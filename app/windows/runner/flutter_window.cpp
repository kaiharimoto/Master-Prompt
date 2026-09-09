#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // `masterprompt/platform`, and it does one thing: hold the machine awake
  // while a run is going. A twelve-hour unattended run on a laptop that sleeps
  // at hour three did not fail — it stopped, and the log ends mid-sentence.
  //
  // Which run is active, and when, is decided in Dart. This end is deliberately
  // incapable of deciding anything: none of it can be executed by a test on the
  // Linux runner, and the same shape of gap is what shipped an invalid session
  // id once already.
  platform_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "masterprompt/platform",
      &flutter::StandardMethodCodec::GetInstance());
  platform_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "keepAwake") {
          result->NotImplemented();
          return;
        }

        bool awake = false;
        if (const auto* args =
                std::get_if<flutter::EncodableMap>(call.arguments())) {
          const auto it = args->find(flutter::EncodableValue("awake"));
          if (it != args->end()) {
            if (const bool* value = std::get_if<bool>(&it->second)) {
              awake = *value;
            }
          }
        }

        // ES_CONTINUOUS alone clears the request; with ES_SYSTEM_REQUIRED it
        // holds. The display is deliberately not held — the screen may sleep,
        // and a monitor that never blanks overnight is its own complaint.
        //
        // This is per-thread state, and the handler always runs on the
        // platform thread, so the hold and its release are the same thread's.
        const EXECUTION_STATE state =
            awake ? (ES_CONTINUOUS | ES_SYSTEM_REQUIRED) : ES_CONTINUOUS;
        const bool ok = SetThreadExecutionState(state) != 0;
        result->Success(flutter::EncodableValue(ok));
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Release the hold before the engine goes, whatever Dart managed to do on
  // the way out. A process that exits still holding it leaves nothing behind —
  // the request dies with the thread — but clearing it here means the window
  // closing is enough on its own.
  SetThreadExecutionState(ES_CONTINUOUS);

  platform_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
