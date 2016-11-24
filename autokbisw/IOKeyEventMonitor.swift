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

class IOKeyEventMonitor{
    private
    let hidManager:IOHIDManager
    let match:CFMutableDictionary

    private class func createDeviceMatchingDictionary( usagePage:Int,  usage:Int ) -> CFMutableDictionary {
        let dict = [
            kIOHIDDeviceUsageKey:usage,
            kIOHIDDeviceUsagePageKey:usagePage
            ] as NSDictionary

        return dict.mutableCopy() as! NSMutableDictionary;
    }

    let myHIDKeyboardCallback: IOHIDValueCallback={
        (context, ioreturn, sender, value) in
        let sender = Unmanaged<IOKeyEventMonitor>.fromOpaque(sender!).takeUnretainedValue()
        print("sender \(sender)")
    }
    init? ( usagePage:Int,  usage:Int ){
        hidManager = IOHIDManagerCreate( kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone) );
        match=IOKeyEventMonitor.createDeviceMatchingDictionary(usagePage:usagePage, usage:usage);
        IOHIDManagerSetDeviceMatching( hidManager, match );
        IOHIDManagerRegisterInputValueCallback( hidManager, myHIDKeyboardCallback, nil );
        IOHIDManagerScheduleWithRunLoop( hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue);
        IOHIDManagerOpen( hidManager,  IOOptionBits(kIOHIDOptionsTypeNone) );
    }


}
