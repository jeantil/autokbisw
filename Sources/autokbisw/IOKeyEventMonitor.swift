// Copyright [2016] Jean Helou
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Carbon
import Foundation
import IOKit
import IOKit.hid
import IOKit.usb

internal final class IOKeyEventMonitor {
    
    private let hidManager: IOHIDManager

    fileprivate let MAPPINGS_DEFAULTS_KEY = "keyboardISMapping"
    fileprivate let notificationCenter: CFNotificationCenter
    fileprivate var lastActiveKeyboard: String = ""
    fileprivate var kb2is: [String: TISInputSource] = [String: TISInputSource]()
    fileprivate var defaults: UserDefaults = UserDefaults.standard
    fileprivate let useLocation: Bool
    fileprivate let verbosity: Int

    init? (usagePage: Int, usage: Int, useLocation: Bool, verbosity: Int) {
        self.useLocation = useLocation
        self.verbosity = verbosity
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        notificationCenter = CFNotificationCenterGetDistributedCenter()
        let deviceMatch: CFMutableDictionary = [kIOHIDDeviceUsageKey: usage, kIOHIDDeviceUsagePageKey: usagePage] as NSMutableDictionary
        IOHIDManagerSetDeviceMatching(hidManager, deviceMatch)
        loadMappings()
    }

    deinit {
        self.saveMappings()
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterInputValueCallback(hidManager, Optional.none, context)
        CFNotificationCenterRemoveObserver(notificationCenter, context, CFNotificationName(kTISNotifySelectedKeyboardInputSourceChanged), nil)
    }

    func start() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        observeIputSourceChangedNotification(context: context)
        registerHIDKeyboardCallback(context: context)

        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)
        IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func observeIputSourceChangedNotification(context: UnsafeMutableRawPointer) {
        let inputSourceChanged: CFNotificationCallback = { _, observer, _, _, _ in
            let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(observer!).takeUnretainedValue()
            selfPtr.onInputSourceChanged()
        }

        CFNotificationCenterAddObserver(notificationCenter,
                                        context,
                                        inputSourceChanged,
                                        kTISNotifySelectedKeyboardInputSourceChanged,
                                        nil,
                                        CFNotificationSuspensionBehavior.deliverImmediately)
    }

    private func registerHIDKeyboardCallback(context: UnsafeMutableRawPointer) {
        let myHIDKeyboardCallback: IOHIDValueCallback = { context, _, sender, _ in
            let selfPtr = Unmanaged<IOKeyEventMonitor>.fromOpaque(context!).takeUnretainedValue()
            let senderDevice = Unmanaged<IOHIDDevice>.fromOpaque(sender!).takeUnretainedValue()

            let vendorId = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDVendorIDKey as CFString))
            let productId = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDProductIDKey as CFString))
            let product = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDProductKey as CFString))
            let manufacturer = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDManufacturerKey as CFString))
            let serialNumber = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDSerialNumberKey as CFString))
            let locationId = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDLocationIDKey as CFString))
            let uniqueId = String(describing: IOHIDDeviceGetProperty(senderDevice, kIOHIDUniqueIDKey as CFString))

            let keyboard = selfPtr.useLocation ?
                "\(product)-[\(vendorId)-\(productId)-\(manufacturer)-\(serialNumber)-\(locationId)]" :
                "\(product)-[\(vendorId)-\(productId)-\(manufacturer)-\(serialNumber)]"

            if selfPtr.verbosity >= TRACE {
                print("received event from keyboard \(keyboard) - \(locationId) - \(uniqueId)")
            }
            selfPtr.onKeyboardEvent(keyboard: keyboard)
        }

        IOHIDManagerRegisterInputValueCallback(hidManager, myHIDKeyboardCallback, context)
    }
}

extension IOKeyEventMonitor {
    func restoreInputSource(keyboard: String) {
        if let targetIs = kb2is[keyboard] {
            if verbosity >= DEBUG {
                print("set input source to \(targetIs) for keyboard \(keyboard)")
            }
            TISSelectInputSource(targetIs)
        } else {
            storeInputSource(keyboard: keyboard)
        }
    }

    func storeInputSource(keyboard: String) {
        let currentSource: TISInputSource = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
        kb2is[keyboard] = currentSource
        saveMappings()
    }

    func onInputSourceChanged() {
        storeInputSource(keyboard: lastActiveKeyboard)
    }

    func onKeyboardEvent(keyboard: String) {
        guard lastActiveKeyboard != keyboard else { return }

        restoreInputSource(keyboard: keyboard)
        lastActiveKeyboard = keyboard
    }

    func loadMappings() {
        let selectableIsProperties = [
            kTISPropertyInputSourceIsEnableCapable: true,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
        ] as CFDictionary
        let inputSources = TISCreateInputSourceList(selectableIsProperties, false).takeUnretainedValue() as! Array<TISInputSource>

        let inputSourcesById = inputSources.reduce([String: TISInputSource]()) { dict, inputSource -> [String: TISInputSource] in
            var dict = dict
            if let id = unmanagedStringToString(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)) {
                dict[id] = inputSource
            }
            return dict
        }

        if let mappings = self.defaults.dictionary(forKey: MAPPINGS_DEFAULTS_KEY) {
            for (keyboardId, inputSourceId) in mappings {
                kb2is[keyboardId] = inputSourcesById[String(describing: inputSourceId)]
            }
        }
    }

    func saveMappings() {
        let mappings = kb2is.mapValues(is2Id)
        defaults.set(mappings, forKey: MAPPINGS_DEFAULTS_KEY)
    }

    private func is2Id(_ inputSource: TISInputSource) -> String? {
        return unmanagedStringToString(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID))!
    }

    func unmanagedStringToString(_ p: UnsafeMutableRawPointer?) -> String? {
        if let cfValue = p {
            let value = Unmanaged.fromOpaque(cfValue).takeUnretainedValue() as CFString
            if CFGetTypeID(value) == CFStringGetTypeID() {
                return value as String
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}
