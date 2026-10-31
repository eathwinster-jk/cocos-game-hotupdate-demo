// 热更新 Demo 主页面：配置版本清单、检查更新、展示更新进度并以游客身份打开游戏。
package com.eath.cocosgamehotupdatedemo;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.eath.cocosgamesdk.CocosGameActivity;
import com.eath.cocosgamesdk.CocosGameSDK;
import com.eath.cocosgamesdk.GameSDKConfig;
import com.eath.cocosgamesdk.GameSessionConfig;
import com.eath.cocosgamesdk.GameUpdateListener;

public final class MainActivity extends Activity {
    private static final String LOG_TAG = "HotUpdateDemo";
    private static final String GAME_ID = "niuniu";
    private static final String STATE_CHECKING = "checking";
    private static final String STATE_DOWNLOADING = "downloading";
    private static final String STATE_INSTALLED = "installed";
    private static final String STATE_UP_TO_DATE = "upToDate";
    private static final int BYTES_PER_KILOBYTE = 1024;
    private TextView statusView;

    /** SDK 已把回调切回主线程，可以直接刷新界面。 */
    private final GameUpdateListener updateListener = new GameUpdateListener() {
        @Override
        public void onUpdateProgress(String gameId, String state, long receivedBytes, long totalBytes) {
            Log.i(LOG_TAG, "更新进度 gameId=" + gameId + ", state=" + state + ", " + receivedBytes + "/" + totalBytes);
            statusView.setText(createProgressText(state, receivedBytes, totalBytes));
        }

        @Override
        public void onUpdateFailed(String gameId, int code, String message) {
            Log.w(LOG_TAG, "更新失败 gameId=" + gameId + ", code=" + code + ", message=" + message);
            statusView.setText(getString(R.string.update_failed, code, message));
        }
    };

    /** 用 Demo 专用清单初始化 SDK 并创建页面。 */
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        CocosGameSDK sdk = CocosGameSDK.getInstance();
        sdk.initialize(this, new GameSDKConfig(BuildConfig.MODULE_CATALOG_URL));
        sdk.setUpdateListener(updateListener);
        setContentView(createContentView());
    }

    /** 创建标题、清单地址、更新状态和操作按钮。 */
    private LinearLayout createContentView() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(24), dp(40), dp(24), dp(24));
        root.addView(createText(getString(R.string.title), 24), createItemParams());
        root.addView(createText(getString(R.string.catalog_url, BuildConfig.MODULE_CATALOG_URL), 13), createItemParams());
        statusView = createText(getString(R.string.update_idle), 16);
        root.addView(statusView, createItemParams());
        root.addView(createButton(R.string.check_update, () -> CocosGameSDK.getInstance().checkGameUpdate(GAME_ID)),
            createItemParams());
        root.addView(createButton(R.string.open_game, this::openGuestGame), createItemParams());
        root.addView(createText(getString(R.string.apply_hint), 13), createItemParams());
        return root;
    }

    /** 把更新状态转换为页面文案。 */
    private String createProgressText(String state, long receivedBytes, long totalBytes) {
        if (STATE_CHECKING.equals(state)) return getString(R.string.update_checking);
        if (STATE_DOWNLOADING.equals(state)) {
            return getString(R.string.update_downloading, receivedBytes / BYTES_PER_KILOBYTE, totalBytes / BYTES_PER_KILOBYTE);
        }
        if (STATE_INSTALLED.equals(state)) return getString(R.string.update_installed);
        if (STATE_UP_TO_DATE.equals(state)) return getString(R.string.update_up_to_date);
        return state;
    }

    /** 以游客身份打开直播间牌桌；打开时 SDK 会使用已安装的最新模块，并在后台检查新版本。 */
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
            CocosGameSDK.getInstance().openGame(this, GAME_ID, session);
        } catch (IllegalArgumentException error) {
            Log.e(LOG_TAG, "游客会话校验失败", error);
            Toast.makeText(this, R.string.invalid_session, Toast.LENGTH_LONG).show();
        }
    }

    /** 游戏会话失效返回时提示原因。 */
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != CocosGameSDK.GAME_REQUEST_CODE || resultCode != RESULT_CANCELED) return;
        if (data == null || !data.hasExtra(CocosGameActivity.EXTRA_SESSION_ERROR)) return;
        String message = data.getStringExtra(CocosGameActivity.EXTRA_SESSION_ERROR);
        Toast.makeText(this, getString(R.string.session_invalid, message), Toast.LENGTH_LONG).show();
    }

    /** 页面销毁时注销更新监听，避免持有已销毁的页面。 */
    @Override
    protected void onDestroy() {
        CocosGameSDK.getInstance().setUpdateListener(null);
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
        params.topMargin = dp(12);
        return params;
    }

    /** 将 dp 转换为像素。 */
    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
