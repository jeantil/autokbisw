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

final internal class IOKeyEventMonitor {
  private let hidManager: IOHIDManager
  
  fileprivate let notificationCenter: CFNotificationCenter
  fileprivate var lastActiveKeyboard: String = ""
  fileprivate var kb2is: [String: TISInputSource] = [String: TISInputSource]()

  init? ( usagePage: Int, usage: Int) {
    hidManager = IOHIDManagerCreate( kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone));
    notificationCenter = CFNotificationCenterGetDistributedCenter();
    let deviceMatch: CFMutableDictionary = [kIOHIDDeviceUsageKey: usage, kIOHIDDeviceUsagePageKey: usagePage] as NSMutableDictionary
    IOHIDManagerSetDeviceMatching( hidManager, deviceMatch);
  }

  deinit {
    // FIXME find out how to pass nil as an IOKit.IOHIDValueCallback to unregister the callback
    let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque());
    //IOHIDManagerRegisterInputValueCallback( hidManager, nil , context);
    CFNotificationCenterRemoveObserver(notificationCenter, context, CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged), nil);
  }

  func start() -> Void {
    let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque());
    observeIputSourceChangedNotification(context: context);
    
    let myHIDKeyboardCallback: IOHIDValueCallback = {
      (context, ioreturn, sender, value) in
      let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(context!).takeUnretainedValue();
      let senderDevice = Unmanaged<IOHIDDevice>.fromOpaque(sender!).takeUnretainedValue();

      let vendorId = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDVendorIDKey as CFString));
      let productId = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDProductIDKey as CFString));
      let product = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDProductKey as CFString));
      let keyboard = "\(product)[\(vendorId)-\(productId)]";
      selfPtr.onKeyboardEvent(keyboard: keyboard);

    }

    IOHIDManagerRegisterInputValueCallback( hidManager, myHIDKeyboardCallback, context);
    IOHIDManagerScheduleWithRunLoop( hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue);
    IOHIDManagerOpen( hidManager, IOOptionBits(kIOHIDOptionsTypeNone));
  }
  
  private func observeIputSourceChangedNotification(context:UnsafeMutableRawPointer){
    let inputSourceChanged: CFNotificationCallback = {
      (center, observer, name, notif, userInfo) in
      let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(observer!).takeUnretainedValue();
      selfPtr.onInputSourceChanged()
    }
    
    CFNotificationCenterAddObserver(notificationCenter,
                                    context, inputSourceChanged,
                                    kTISNotifySelectedKeyboardInputSourceChanged, nil,
                                    CFNotificationSuspensionBehavior.deliverImmediately);

  }
  
  
}

extension IOKeyEventMonitor {
  
  
  
  func restoreInputSource(keyboard: String) -> Void {
    if let targetIs = kb2is[keyboard] {
      //print("set input source to \(targetIs) for keyboard \(keyboard)");
      TISSelectInputSource(targetIs)
    } else {
      self.storeInputSource(keyboard: keyboard);
    }
  }
  
  func storeInputSource(keyboard: String) -> Void {
    let currentSource: TISInputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue();
    kb2is[keyboard] = currentSource;
  }
  
  func onInputSourceChanged() -> Void {
    self.storeInputSource(keyboard: self.lastActiveKeyboard);
  }
  
  func onKeyboardEvent(keyboard: String) -> Void {
    guard self.lastActiveKeyboard != keyboard else { return }
      
    self.restoreInputSource(keyboard: keyboard);
    self.lastActiveKeyboard = keyboard;
  }
}
