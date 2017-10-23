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


let cli = CommandLine()

cli.addOptions(UserOptions.useLocation, UserOptions.verbosity, UserOptions.help)

do {
  try cli.parse()
} catch {
  cli.printUsage(error)
  exit(EX_USAGE)
}

if(UserOptions.help.value){
  cli.printUsage()
}else{
  if(UserOptions.verbosity.value > 0){
    print("starting with useLocation:\(UserOptions.useLocation.value) - verbosity:\(UserOptions.verbosity.value)");
  }
  let userOptions = UserOptions(useLocation: UserOptions.useLocation.value,verbosity: UserOptions.verbosity.value)
  let monitor = IOKeyEventMonitor(usagePage: 0x01, usage: 6, _userOptions: userOptions);
  monitor?.start();
  CFRunLoopRun()
}
