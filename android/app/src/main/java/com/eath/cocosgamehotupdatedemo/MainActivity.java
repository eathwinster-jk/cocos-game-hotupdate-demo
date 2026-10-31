// 热更新 Demo 主页面：点击打开游戏时先检查并下载新版本、展示进度，完成后以游客身份把游戏内嵌在页面顶部，并在下方显示模块版本；可清除已下载的模块后重新热更。
package com.eath.cocosgamehotupdatedemo;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import com.eath.cocosgamesdk.CocosGameSDK;
import com.eath.cocosgamesdk.GameHostListener;
import com.eath.cocosgamesdk.GameSessionConfig;
import com.eath.cocosgamesdk.hotupdate.GameHotUpdate;
import com.eath.cocosgamesdk.hotupdate.GameUpdateListener;

public final class MainActivity extends Activity implements GameHostListener {
    private static final String LOG_TAG = "HotUpdateDemo";
    private static final String GAME_ID = "niuniu";
    private static final float TABLE_HEIGHT_RATIO = 211F / 375F;
    private static final int BYTES_PER_KILOBYTE = 1024;
    private static final int PROGRESS_MAX = 100;
    private GameHotUpdate hotUpdate;
    private FrameLayout tableContainer;
    private TextView statusView;
    private ProgressBar progressBar;
    private TextView versionView;
    private Button openButton;
    private Button closeButton;
    private Button clearButton;
    private boolean isPreparingGame;
    private boolean isGameOpen;

    /** 热更新库已把回调切回主线程，可以直接刷新界面。 */
    private final GameUpdateListener updateListener = new GameUpdateListener() {
        @Override
        public void onUpdateProgress(String gameId, String state, long receivedBytes, long totalBytes) {
            Log.i(LOG_TAG, "更新进度 gameId=" + gameId + ", state=" + state + ", " + receivedBytes + "/" + totalBytes);
            statusView.setText(createProgressText(state, receivedBytes, totalBytes));
            if (totalBytes > 0) progressBar.setProgress((int) (receivedBytes * PROGRESS_MAX / totalBytes));
            if (GameHotUpdate.STATE_INSTALLED.equals(state) || GameHotUpdate.STATE_UP_TO_DATE.equals(state)) {
                progressBar.setProgress(PROGRESS_MAX);
                finishPreparingGame();
            }
        }

        @Override
        public void onUpdateFailed(String gameId, int code, String message) {
            Log.w(LOG_TAG, "更新失败 gameId=" + gameId + ", code=" + code + ", message=" + message);
            statusView.setText(getString(R.string.update_failed, code, message));
            finishPreparingGame();
        }
    };

    /** 初始化 SDK，用 Demo 专用清单开启热更新（须在打开游戏前），并创建页面。 */
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        CocosGameSDK.getInstance().initialize(this);
        hotUpdate = GameHotUpdate.install(this, BuildConfig.MODULE_CATALOG_URL);
        hotUpdate.setUpdateListener(updateListener);
        CocosGameSDK.getInstance().setHostListener(this);
        setContentView(createContentView());
        updateVersionText();
        updateGameButtons();
    }

    /** 创建页面：顶部游戏容器 + 下方操作区。 */
    private LinearLayout createContentView() {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        tableContainer = createTableContainer();
        int width = getResources().getDisplayMetrics().widthPixels;
        page.addView(tableContainer, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, Math.round(width * TABLE_HEIGHT_RATIO)));
        page.addView(createControlPanel());
        return page;
    }

    /** 创建游戏容器；未打开游戏时显示提示，游戏视图打开后覆盖在提示之上。 */
    private FrameLayout createTableContainer() {
        FrameLayout container = new FrameLayout(this);
        container.setBackgroundColor(Color.BLACK);
        TextView placeholder = createText(getString(R.string.game_placeholder), 15);
        placeholder.setTextColor(Color.LTGRAY);
        container.addView(placeholder, new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER));
        return container;
    }

    /** 创建标题、清单地址、更新状态、进度条、模块版本和操作按钮。 */
    private LinearLayout createControlPanel() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(20), dp(4), dp(20), dp(20));
        panel.addView(createText(getString(R.string.title), 22), createItemParams());
        panel.addView(createText(getString(R.string.catalog_url, BuildConfig.MODULE_CATALOG_URL), 12), createItemParams());
        statusView = createText(getString(R.string.update_idle), 16);
        panel.addView(statusView, createItemParams());
        progressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setMax(PROGRESS_MAX);
        panel.addView(progressBar, createItemParams());
        versionView = createText("", 16);
        panel.addView(versionView, createItemParams());
        openButton = createButton(R.string.open_game, this::prepareAndOpenGame);
        panel.addView(openButton, createItemParams());
        closeButton = createButton(R.string.close_game, () -> CocosGameSDK.getInstance().closeGame());
        panel.addView(closeButton, createItemParams());
        clearButton = createButton(R.string.clear_modules, this::clearInstalledModules);
        panel.addView(clearButton, createItemParams());
        panel.addView(createText(getString(R.string.apply_hint), 13), createItemParams());
        return panel;
    }

    /** 清除已下载的模块，下次打开游戏会回到内置版本并重新下载。 */
    private void clearInstalledModules() {
        if (!hotUpdate.clearInstalledModules(GAME_ID)) {
            Toast.makeText(this, R.string.clear_modules_busy, Toast.LENGTH_SHORT).show();
            return;
        }
        statusView.setText(R.string.update_idle);
        progressBar.setProgress(0);
        updateVersionText();
        Toast.makeText(this, R.string.clear_modules_done, Toast.LENGTH_SHORT).show();
    }

    /** 先检查并下载新版本，结束（已安装、已是最新或失败）后再打开游戏。 */
    private void prepareAndOpenGame() {
        isPreparingGame = true;
        progressBar.setProgress(0);
        updateGameButtons();
        hotUpdate.checkForUpdate(GAME_ID);
    }

    /** 下载流程结束后打开游戏；只响应本页面发起的那一次准备。 */
    private void finishPreparingGame() {
        if (!isPreparingGame) return;
        isPreparingGame = false;
        openGuestGame();
    }

    /** 以游客身份把直播间牌桌嵌入顶部容器，使用刚刚安装的最新模块。 */
    private void openGuestGame() {
        try {
            String androidId = Settings.Secure.getString(getContentResolver(), Settings.Secure.ANDROID_ID);
            GameSessionConfig session = GameSessionConfig.createGuest(
                BuildConfig.GAME_WS_URL,
                BuildConfig.GAME_API_URL,
                "android-" + androidId,
                BuildConfig.GAME_GUEST_SCENE_ID,
                0,
                BuildConfig.VERSION_NAME,
                "Android");
            updateVersionText();
            CocosGameSDK.getInstance().openGame(this, tableContainer, GAME_ID, session);
            isGameOpen = true;
        } catch (IllegalArgumentException error) {
            Log.e(LOG_TAG, "游客会话校验失败", error);
            Toast.makeText(this, R.string.invalid_session, Toast.LENGTH_LONG).show();
        }
        updateGameButtons();
    }

    /** 显示下次打开会加载的模块版本。 */
    private void updateVersionText() {
        int version = hotUpdate.getInstalledVersion(GAME_ID);
        versionView.setText(version > 0 ? getString(R.string.module_version_installed, version) : getString(R.string.module_version_builtin));
    }

    /** 根据游戏是否打开（或正在准备）切换按钮可用状态。 */
    private void updateGameButtons() {
        openButton.setEnabled(!isGameOpen && !isPreparingGame);
        closeButton.setEnabled(isGameOpen);
        clearButton.setEnabled(!isGameOpen && !isPreparingGame);
    }

    /** 把更新状态转换为页面文案。 */
    private String createProgressText(String state, long receivedBytes, long totalBytes) {
        if (GameHotUpdate.STATE_CHECKING.equals(state)) return getString(R.string.update_checking);
        if (GameHotUpdate.STATE_DOWNLOADING.equals(state)) {
            return getString(R.string.update_downloading, receivedBytes / BYTES_PER_KILOBYTE, totalBytes / BYTES_PER_KILOBYTE);
        }
        if (GameHotUpdate.STATE_INSTALLED.equals(state)) return getString(R.string.update_installed);
        if (GameHotUpdate.STATE_UP_TO_DATE.equals(state)) return getString(R.string.update_up_to_date);
        return state;
    }

    /** 游客模式无需处理通用事件，只记录日志。 */
    @Override
    public void onGameEvent(String gameId, String event, String payloadJson) {
        Log.i(LOG_TAG, "游戏事件 gameId=" + gameId + ", event=" + event);
    }

    /** 大厅会话失效时提示原因。 */
    @Override
    public void onSessionInvalid(String gameId, String message) {
        Toast.makeText(this, getString(R.string.session_invalid, message), Toast.LENGTH_LONG).show();
    }

    /** 牌桌关闭后回到空白游戏区。 */
    @Override
    public void onGameClosed(String gameId) {
        isGameOpen = false;
        updateGameButtons();
    }

    /** 返回键先交给牌桌：全屏退回竖屏，未消费时再关闭页面。 */
    @Override
    public void onBackPressed() {
        if (CocosGameSDK.getInstance().onBackPressed()) return;
        super.onBackPressed();
    }

    /** 页面销毁时注销监听，避免持有已销毁的页面。 */
    @Override
    protected void onDestroy() {
        hotUpdate.setUpdateListener(null);
        CocosGameSDK.getInstance().setHostListener(null);
        super.onDestroy();
    }

    /** 创建文字控件。 */
    private TextView createText(String text, int textSizeSp) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(textSizeSp);
        return view;
    }

    /** 创建按钮。 */
    private Button createButton(int textResourceId, Runnable action) {
        Button button = new Button(this);
        button.setText(textResourceId);
        button.setAllCaps(false);
        button.setOnClickListener(view -> action.run());
        return button;
    }

    /** 创建统一纵向布局参数。 */
    private LinearLayout.LayoutParams createItemParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT);
        params.topMargin = dp(10);
        return params;
    }

    /** 将 dp 转换为像素。 */
    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
