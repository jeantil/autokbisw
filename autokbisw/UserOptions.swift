//Copyright [2017] Jean Helou
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


internal struct UserOptions {
  static let useLocation = BoolOption(shortFlag: "l",
                                      longFlag: "location",
                                      helpMessage: "Uses locationId to identify keyboards (defaults to false).\n\n" +
                                                   "Note that the locationId changes when you plug a keyboard in a different port." +
                                                   "Therefore using the locationId in the keyboards identifiers means the " +
                                                   "configured language will be associated to a keyboard on a specific port.")
  static let help = BoolOption(shortFlag: "h", longFlag: "help",
                        helpMessage: "Prints this help message.")
  static let verbosity = CounterOption(shortFlag: "v", longFlag: "verbose",
                                helpMessage: "Print verbose messages. Specify multiple times to increase verbosity.")
  
  static let DEBUG: Int=1
  static let TRACE: Int=2
  
  let useLocation: Bool
  let verbosity: Int
}
