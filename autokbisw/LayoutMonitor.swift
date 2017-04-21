//Copyright [2016] Jean Helou
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.

import Foundation
import Carbon
import IOKit
import IOKit.usb
import IOKit.hid

final internal class LayoutMonitor {
  private let managerHID: IOHIDManager
  private let notificationCenter: CFNotificationCenter
  
  fileprivate var lastActiveKeyboard = ""
  fileprivate var kb2is = [String: TISInputSource]()
  
  init(usagePage: Int, usage: Int) {
    managerHID = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    notificationCenter = CFNotificationCenterGetDistributedCenter()
    
    let match: CFMutableDictionary = [kIOHIDDeviceUsageKey: usage, kIOHIDDeviceUsagePageKey: usagePage] as NSMutableDictionary
    IOHIDManagerSetDeviceMatching(managerHID, match)
  }
  
  func start() {
    let keyboardEventDidOccur: IOHIDValueCallback = { (context, _, sender, _) in
      let senderDevice = Unmanaged<IOHIDDevice>.fromOpaque(sender!).takeUnretainedValue()
      let vendorId  = IOHIDDeviceGetProperty(senderDevice, kIOHIDVendorIDKey as CFString) as! String
      let productId = IOHIDDeviceGetProperty(senderDevice, kIOHIDProductIDKey as CFString) as! String
      let product   = IOHIDDeviceGetProperty(senderDevice, kIOHIDProductKey as CFString) as! String
      let keyboard = "\(product)[\(vendorId)-\(productId)]"
      
      let selfPtr = Unmanaged<LayoutMonitor>.fromOpaque(context!).takeUnretainedValue()
      selfPtr.onKeyboardEvent(keyboard: keyboard)
    }
    
    let inputSourceDidChange: CFNotificationCallback = { (_, observer, _, _, _) in
      let selfPtr = Unmanaged<LayoutMonitor>.fromOpaque(observer!).takeUnretainedValue()
      selfPtr.onInputSourceChanged()
    }
    
    let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    CFNotificationCenterAddObserver(notificationCenter, context, inputSourceDidChange, kTISNotifySelectedKeyboardInputSourceChanged, nil, CFNotificationSuspensionBehavior.deliverImmediately)
    IOHIDManagerRegisterInputValueCallback(managerHID, keyboardEventDidOccur, context)
    IOHIDManagerScheduleWithRunLoop(managerHID, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)
    IOHIDManagerOpen(managerHID, IOOptionBits(kIOHIDOptionsTypeNone))
  }
  
  deinit { // FIXME find out how to pass nil as an IOKit.IOHIDValueCallback to unregister the callback
    let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    //IOHIDManagerRegisterInputValueCallback(hidManager, nil , context)
    CFNotificationCenterRemoveObserver(notificationCenter, context, CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged), nil)
  }
}

extension LayoutMonitor {
  func restoreInputSource(keyboard: String) {
    guard let targetIs = kb2is[keyboard] else { return storeInputSource(keyboard: keyboard) }
    // print("set input source to \(targetIs) for keyboard \(keyboard)")
    TISSelectInputSource(targetIs)
  }
  
  func storeInputSource(keyboard: String) {
    let currentSource: TISInputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
    kb2is[keyboard] = currentSource
  }
  
  func onInputSourceChanged() {
    storeInputSource(keyboard: lastActiveKeyboard)
  }
  
  func onKeyboardEvent(keyboard: String) {
    guard lastActiveKeyboard != keyboard else { return }
    
    // print("Active keyboard changed from \(lastActiveKeyboard) to \(keyboard)")
    restoreInputSource(keyboard: keyboard)
    lastActiveKeyboard = keyboard
  }
}
