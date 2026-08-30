#ifndef RUNNER_RUN_LOOP_H_
#define RUNNER_RUN_LOOP_H_

#include <windows.h>

#include <chrono>
#include <set>

// A runloop that will dispatch messages to the Flutter engine.
class RunLoop {
 public:
  RunLoop();
  ~RunLoop();

  // Prevent copying.
  RunLoop(const RunLoop&) = delete;
  RunLoop& operator=(const RunLoop&) = delete;

  // Runs the run loop until the application quits.
  void Run();

 private:
  using TimePoint = std::chrono::steady_clock::time_point;

  struct FlutterTimeWaitable {
    TimePoint target_time;
    void* user_data;

    bool operator<(const FlutterTimeWaitable& other) const {
      return target_time < other.target_time;
    }
  };

  // Dispatches all expired tasks to the Flutter engine.
  void ProcessPendingTasks();

  std::set<FlutterTimeWaitable> flutter_waitable_tasks_;
};

#endif  // RUNNER_RUN_LOOP_H_

