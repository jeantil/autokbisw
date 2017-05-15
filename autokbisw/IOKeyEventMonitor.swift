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


struct IOKeyEventMonitorContext {
  var lastSeenSender: String
  init(lastSeenSender: String) {
    self.lastSeenSender = lastSeenSender
  }
}

class IOKeyEventMonitor {
  private
  let hidManager: IOHIDManager
  let notificationCenter: CFNotificationCenter
  let match: CFMutableDictionary
  var defaults: UserDefaults

  var lastActiveKeyboard: String = ""
  var kb2is: [String: TISInputSource] = [String: TISInputSource]()


  private class func createDeviceMatchingDictionary( usagePage: Int, usage: Int) -> CFMutableDictionary {
    let dict = [
      kIOHIDDeviceUsageKey: usage,
      kIOHIDDeviceUsagePageKey: usagePage
    ] as NSDictionary

    return dict.mutableCopy() as! NSMutableDictionary;
  }

  // Trefex 2017
  // Parts adapted from github.com/noraesae/kawa. MIT 2016
  func restorePreferences() -> Void {
    // Load list of all input sources and filter it to only the proper ones
    let inputSourceNSArray = TISCreateInputSourceList(nil, false).takeRetainedValue() as NSArray
    let inputSourceList = inputSourceNSArray as! [TISInputSource]
    let inputSources = inputSourceList.filter(IOKeyEventMonitor.isProperInputSource)

    // Create a map of inputSource session ids and input source ids
    var inputMap: [String: TISInputSource] = [String: TISInputSource]()
    for inputSource in inputSources {
      var id: String = ""
      id = IOKeyEventMonitor.getProperty(inputSource, kTISPropertyInputSourceID)!
      inputMap[id] = inputSource;
    }
    
    // Repopulate kb2is from stored settings
    if let tempkb2is = self.defaults.object(forKey: "KBSwitcher") as? [String: String] {
      for tempItem in tempkb2is.keys {
        let sessionInputSourceID: String
        sessionInputSourceID = tempkb2is[tempItem]!;
        kb2is[tempItem] = inputMap[sessionInputSourceID];
      }
    }
  }
  
  init? ( usagePage: Int, usage: Int) {
    hidManager = IOHIDManagerCreate( kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone));
    notificationCenter = CFNotificationCenterGetDistributedCenter();
    match = IOKeyEventMonitor.createDeviceMatchingDictionary(usagePage: usagePage, usage: usage);
    IOHIDManagerSetDeviceMatching( hidManager, match);
    self.defaults = UserDefaults.standard;
    self.restorePreferences();
  }

  deinit {
    // FIXME find out how to pass nil as an IOKit.IOHIDValueCallback to unregister the callback
    let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque());
    //IOHIDManagerRegisterInputValueCallback( hidManager, nil , context);
    CFNotificationCenterRemoveObserver(notificationCenter, context, CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged), nil);
  }

  func restoreInputSource(keyboard: String) -> Void {
    if let targetIs = kb2is[keyboard] {
      //print("set input source to \(targetIs) for keyboard \(keyboard)");
      TISSelectInputSource(targetIs)
    } else {
      self.storeInputSource(keyboard: keyboard);
    }
  }
  
  // github.com/noraesae/kawa. MIT 2016
  static func getProperty<T>(_ source: TISInputSource, _ key: CFString) -> T? {
    let cfType = TISGetInputSourceProperty(source, key)
    if (cfType != nil) {
      return Unmanaged<AnyObject>.fromOpaque(cfType!).takeUnretainedValue() as? T
    } else {
      return nil
    }
  }
  
  // github.com/noraesae/kawa. MIT 2016
  static func isProperInputSource(_ source: TISInputSource) -> Bool {
    let category: String = getProperty(source, kTISPropertyInputSourceCategory)!
    let selectable: Bool = getProperty(source, kTISPropertyInputSourceIsSelectCapable)!
    return category == (kTISCategoryKeyboardInputSource as String) && selectable
  }

  func storeInputSource(keyboard: String) -> Void {
    let currentSource: TISInputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue();
    kb2is[keyboard] = currentSource;
    
    // Prepare kb2is for saving by replacing session id with input source id
    var savekb2is: [String: String] = [String: String]();
    
    for item in kb2is.keys {
      var id: String = ""
      id = IOKeyEventMonitor.getProperty(kb2is[item]!, kTISPropertyInputSourceID)!;
      savekb2is[item] = id;
    }
    
    self.defaults.set(savekb2is, forKey: "KBSwitcher");
    self.defaults.synchronize();
  }

  func onInputSourceChanged() -> Void {
    self.storeInputSource(keyboard: self.lastActiveKeyboard);
  }

  func onKeyboardEvent(keyboard: String) -> Void {
    if(self.lastActiveKeyboard != keyboard) {
      //print("Active keyboard changed from \(self.lastActiveKeyboard) to \(keyboard)");
      self.restoreInputSource(keyboard: keyboard);
      self.lastActiveKeyboard = keyboard;
    }
  }


  func start() -> Void {
    let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque());
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
    let inputSourceChanged: CFNotificationCallback = {
      (center, observer, name, notif, userInfo) in
      let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(observer!).takeUnretainedValue();
      selfPtr.onInputSourceChanged()
    }

    CFNotificationCenterAddObserver(notificationCenter,
                                    context, inputSourceChanged,
                                    kTISNotifySelectedKeyboardInputSourceChanged, nil,
                                    CFNotificationSuspensionBehavior.deliverImmediately);


    IOHIDManagerRegisterInputValueCallback( hidManager, myHIDKeyboardCallback, context);
    IOHIDManagerScheduleWithRunLoop( hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue);
    IOHIDManagerOpen( hidManager, IOOptionBits(kIOHIDOptionsTypeNone));
  }

}
