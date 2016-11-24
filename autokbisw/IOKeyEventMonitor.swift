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
import IOKit
import IOKit.usb
import IOKit.hid

struct IOKeyEventMonitorContext{
  var lastSeenSender:String
  init(lastSeenSender:String){
    self.lastSeenSender=lastSeenSender
  }
}

class IOKeyEventMonitor{
  private
  let hidManager:IOHIDManager
  let match:CFMutableDictionary
  var lastSeenSender:String=""
  
  private class func createDeviceMatchingDictionary( usagePage:Int,  usage:Int ) -> CFMutableDictionary {
    let dict = [
      kIOHIDDeviceUsageKey:usage,
      kIOHIDDeviceUsagePageKey:usagePage
      ] as NSDictionary
    
    return dict.mutableCopy() as! NSMutableDictionary;
  }
  
  init? ( usagePage:Int,  usage:Int ){
    hidManager = IOHIDManagerCreate( kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone) );
    match=IOKeyEventMonitor.createDeviceMatchingDictionary(usagePage:usagePage, usage:usage);
    IOHIDManagerSetDeviceMatching( hidManager, match );
  }
  deinit {
    // FIXME find out how to pass nil as an IOKit.IOHIDValueCallback to unregister the callback
    //    IOHIDManagerRegisterInputValueCallback( hidManager, nil as IOKit.IOHIDValueCallback, nil);
  }
  func start()-> Void {
    
    let myHIDKeyboardCallback: IOHIDValueCallback={
      (context, ioreturn, sender, value) in
      let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(context!).takeUnretainedValue();
      let sender = Unmanaged<IOKeyEventMonitor>.fromOpaque(sender!).takeUnretainedValue();
      let senderStr = String(describing:sender);
      
      if(selfPtr.lastSeenSender != senderStr){
        print("sender \(context!)");
        print("sender \(sender)");
        selfPtr.lastSeenSender = senderStr;
      }
    }
    
    let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque());
    print("start context \(context)");
    IOHIDManagerRegisterInputValueCallback( hidManager, myHIDKeyboardCallback, context);
    IOHIDManagerScheduleWithRunLoop( hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue);
    IOHIDManagerOpen( hidManager,  IOOptionBits(kIOHIDOptionsTypeNone) );
  }
  
}
