package dev.kadenthompson.marquee.session

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit

/** Non-secret UI preferences (the remembered shelf, appearance). Never the server or token. */
class Prefs(context: Context) {
    private val sp = context.getSharedPreferences("ui", Context.MODE_PRIVATE)

    var appearance by mutableStateOf(sp.getString("appearance", "dark") ?: "dark"); private set
    fun chooseAppearance(v: String) { appearance = v; sp.edit { putString("appearance", v) } }

    fun string(key: String, default: String) = sp.getString(key, default) ?: default
    fun putString(key: String, value: String) = sp.edit { putString(key, value) }
    fun bool(key: String, default: Boolean) = sp.getBoolean(key, default)
    fun putBool(key: String, value: Boolean) = sp.edit { putBoolean(key, value) }
}
