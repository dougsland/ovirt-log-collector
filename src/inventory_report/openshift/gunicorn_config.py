#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
import multiprocessing

bind = "127.0.0.1:8000"

# Increasing the timeout because some sosreports can be big
# and take up to 15m-20m (or more?) to process.
timeout = "1800" # 1800 seconds is 30 minutes
#debug = True
workers = multiprocessing.cpu_count() * 2 + 1