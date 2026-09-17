package com.example.health_connect

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Shows the app's privacy-policy / permission rationale.
 *
 * It is exported so Health Connect can open it:
 *  - Android 13 and below: androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE
 *  - Android 14+:          android.intent.action.VIEW_PERMISSION_USAGE
 *    (via the ViewPermissionUsageActivity alias declared in AndroidManifest.xml)
 */
class PermissionsRationaleActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(24), dp(24), dp(24))
        }

        content.addView(TextView(this).apply {
            text = getString(R.string.health_connect_privacy_title)
            textSize = 20f
            setTypeface(null, Typeface.BOLD)
        })

        content.addView(TextView(this).apply {
            text = getString(R.string.health_connect_privacy_body)
            textSize = 15f
            setPadding(0, dp(16), 0, 0)
        })

        val openButton = Button(this).apply {
            text = getString(R.string.health_connect_open_privacy_policy)
            setOnClickListener {
                startActivity(
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse(getString(R.string.health_connect_privacy_policy_url)),
                    ),
                )
            }
        }
        openButton.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(24) }
        content.addView(openButton)

        setContentView(ScrollView(this).apply { addView(content) })
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}