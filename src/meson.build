gala_bin_sources = files(
    'DBus.vala',
    'DBusAccelerator.vala',
    'DaemonManager.vala',
    'DesktopIntegration.vala',
    'Dialogs.vala',
    'InternalUtils.vala',
    'KeyboardManager.vala',
    'Main.vala',
    'MediaFeedback.vala',
    'NotificationStack.vala',
    'PantheonShell.vala',
    'PluginManager.vala',
    'ScreenSaverManager.vala',
    'ScreenshotManager.vala',
    'SessionManager.vala',
    'WindowAttentionTracker.vala',
    'WindowGrabTracker.vala',
    'WindowListener.vala',
    'WindowManager.vala',
    'WindowStateSaver.vala',
    'WindowTracker.vala',
    'WorkspaceManager.vala',
    'Zoom.vala',
    'Background/Animation.vala',
    'Background/Background.vala',
    'Background/BackgroundCache.vala',
    'Background/BackgroundContainer.vala',
    'Background/BackgroundManager.vala',
    'Background/BackgroundSource.vala',
    'Background/BlurEffect.vala',
    'Background/SystemBackground.vala',
    'ColorFilters/ColorblindnessCorrectionEffect.vala',
    'ColorFilters/FilterManager.vala',
    'ColorFilters/MonochromeEffect.vala',
    'Gestures/Gesture.vala',
    'Gestures/GestureSettings.vala',
    'Gestures/GestureTracker.vala',
    'Gestures/ScrollBackend.vala',
    'Gestures/ToucheggBackend.vala',
    'HotCorners/Barrier.vala',
    'HotCorners/HotCorner.vala',
    'HotCorners/HotCornerManager.vala',
    'ShellClients/CenteredWindow.vala',
    'ShellClients/HideTracker.vala',
    'ShellClients/ManagedClient.vala',
    'ShellClients/NotificationsClient.vala',
    'ShellClients/PanelClone.vala',
    'ShellClients/PanelWindow.vala',
    'ShellClients/ShellClientsManager.vala',
    'Widgets/DwellClickTimer.vala',
    'Widgets/IconGroup.vala',
    'Widgets/IconGroupContainer.vala',
    'Widgets/MonitorClone.vala',
    'Widgets/MultitaskingView.vala',
    'Widgets/PixelPicker.vala',
    'Widgets/PointerLocator.vala',
    'Widgets/SafeWindowClone.vala',
    'Widgets/ScreenShield.vala',
    'Widgets/SelectionArea.vala',
    'Widgets/Tooltip.vala',
    'Widgets/WindowClone.vala',
    'Widgets/WindowCloneContainer.vala',
    'Widgets/WindowIconActor.vala',
    'Widgets/WindowOverview.vala',
    'Widgets/WindowSwitcher/WindowSwitcher.vala',
    'Widgets/WindowSwitcher/WindowSwitcherIcon.vala',
    'Widgets/WorkspaceClone.vala',
    'Widgets/WorkspaceInsertThumb.vala',
)

gala_bin = executable(
    'gala',
    gala_bin_sources,
    dependencies: [gala_dep, gala_base_dep, pantheon_desktop_shell_dep],
    include_directories: config_inc_dir,
    install_rpath: mutter_typelib_dir,
    install: true,
)
