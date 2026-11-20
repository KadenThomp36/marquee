package dev.kadenthompson.marquee.features.pairing

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Pin
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.BulbRow
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.QuietButton
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.net.ApiError
import dev.kadenthompson.marquee.net.PairedServer
import dev.kadenthompson.marquee.net.ServerAddress
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

private enum class Step { ADDRESS, METHOD, SIGN_IN, CODE }

/**
 * The front door. Until someone types their own server address and proves who they
 * are, this app knows nothing and can reach nothing — no default host, no discovery,
 * no demo mode.
 */
@Composable
fun PairingScreen() {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var step by rememberSaveable { mutableStateOf(Step.ADDRESS) }
    var address by rememberSaveable { mutableStateOf("") }
    var resolved by rememberSaveable { mutableStateOf<String?>(null) }
    var deviceName by rememberSaveable { mutableStateOf(session.suggestedDeviceName) }
    var username by rememberSaveable { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var signUpsOpen by remember { mutableStateOf(false) }

    val host = resolved?.toHttpUrlOrNull()?.host ?: "your server"
    val trimmedName = deviceName.trim().ifEmpty { session.suggestedDeviceName }

    fun back() { error = null; code = ""; step = Step.ADDRESS }

    fun connect() = scope.launch {
        error = null; busy = true
        try {
            val base = ServerAddress.resolve(address)
            resolved = base; address = base
            signUpsOpen = ServerAddress.signUpsOpen(base)
            step = Step.METHOD
        } catch (e: Exception) { error = e.friendly } finally { busy = false }
    }

    fun signIn() = scope.launch {
        val base = resolved ?: return@launch
        error = null; busy = true
        try {
            val r = ServerAddress.postAuth(base, "api/login", buildJsonObject {
                put("username", JsonPrimitive(username.trim())); put("password", JsonPrimitive(password))
                put("device_name", JsonPrimitive(trimmedName)); put("want_token", JsonPrimitive(true))
            })
            // Signing in worked but no token came back: a server that predates native clients.
            val token = r.token ?: throw ApiError.NeedsServerUpdate()
            session.adopt(PairedServer(base, token, r.username ?: username, r.username ?: username, r.isAdmin == true, trimmedName), null)
        } catch (e: ApiError.Http) {
            error = if (e.status == 401) e.message?.takeIf { it.isNotEmpty() } ?: "Wrong username or password." else e.friendly
        } catch (e: Exception) { error = e.friendly } finally { busy = false }
    }

    fun claim() = scope.launch {
        val base = resolved ?: return@launch
        if (code.length != 6 || busy) return@launch
        error = null; busy = true
        try {
            val r = ServerAddress.postAuth(base, "api/pair/claim", buildJsonObject {
                put("code", JsonPrimitive(code)); put("device_name", JsonPrimitive(trimmedName))
            })
            val token = r.token; val user = r.user
            if (token == null || user == null) throw ApiError.NeedsServerUpdate()
            session.adopt(PairedServer(base, token, user.username, user.person.name, user.isAdmin == true, trimmedName), user.person)
        } catch (e: ApiError.Http) {
            code = ""
            // The endpoint isn't there at all — an older server, not a bad code (a bad code is 410).
            error = if (e.status == 404) ApiError.NeedsServerUpdate().message else e.friendly
        } catch (e: Exception) { code = ""; error = e.friendly } finally { busy = false }
    }

    val glow = C.brass.copy(alpha = 0.16f)
    Box(
        Modifier.fillMaxSize().background(C.ground).drawBehind {
            // A single soft brass wash behind the wordmark — the marquee's spill light.
            drawRect(Brush.radialGradient(listOf(glow, Color.Transparent), center = Offset(size.width / 2, size.height * 0.16f), radius = 420.dp.toPx()))
        }
    ) {
        Column(
            Modifier.fillMaxSize().safeDrawingPadding().imePadding().verticalScroll(rememberScrollState()).padding(horizontal = MQ.gutter),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(44.dp))
            BulbRow(9)
            Spacer(Modifier.height(12.dp))
            Text("MARQUEE", style = T.wordmark(38f), color = C.brass)
            Spacer(Modifier.height(10.dp))
            Text(
                when (step) {
                    Step.ADDRESS -> "Connect to your own Marquee server."
                    Step.METHOD -> "How would you like to sign in?"
                    Step.SIGN_IN -> "Sign in to $host."
                    Step.CODE -> "Enter the code from your Marquee web app."
                },
                style = T.sub, color = C.inkSoft, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 24.dp),
            )
            Spacer(Modifier.height(34.dp))

            Column(Modifier.widthIn(max = 460.dp).fillMaxWidth()) {
                AnimatedContent(step, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "step") { s ->
                    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        when (s) {
                            Step.ADDRESS -> {
                                Eyebrow("Server address")
                                val fr = remember { FocusRequester() }
                                MqField(address, { address = it }, "marquee.example.com", Modifier.focusRequester(fr).testTag("pairing.address"),
                                    keyboard = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Go, autoCorrectEnabled = false),
                                    onGo = { if (address.isNotBlank()) connect() })
                                LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
                                Text("Wherever you open Marquee in a browser. A hostname or an address on your home network both work — if you leave off http:// or https://, Marquee tries both.", style = T.caption, color = C.inkMuted)
                                PrimaryButton(if (busy) "Connecting…" else "Connect", { connect() }, Modifier.padding(top = 4.dp).testTag("pairing.connect"), enabled = address.isNotBlank(), busy = busy)
                            }
                            Step.METHOD -> {
                                ConnectedChip(host) { back() }
                                MethodCard("Use a pairing code", "Open Marquee where you're already signed in, go to Settings › Devices, and generate a code. Your password never leaves that browser.", Icons.Filled.Pin, true) { error = null; step = Step.CODE }
                                MethodCard("Sign in with your password", "Your Marquee username and password, the same as the web app.", Icons.Filled.AccountCircle, false) { error = null; step = Step.SIGN_IN }
                                if (signUpsOpen) Text("This server is accepting new sign-ups, so you can also create an account from the web app.", style = T.caption, color = C.inkMuted, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                            }
                            Step.SIGN_IN -> {
                                ConnectedChip(host) { back() }
                                Eyebrow("Username")
                                MqField(username, { username = it }, "username", keyboard = KeyboardOptions(imeAction = ImeAction.Next, autoCorrectEnabled = false))
                                Eyebrow("Password")
                                MqField(password, { password = it }, "password", secret = true, keyboard = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Go), onGo = { signIn() })
                                DeviceNameField(deviceName) { deviceName = it }
                                PrimaryButton("Take your seat", { signIn() }, Modifier.padding(top = 4.dp), enabled = username.isNotEmpty() && password.isNotEmpty(), busy = busy)
                                QuietButton("Use a pairing code instead", { error = null; step = Step.CODE }, Modifier.align(Alignment.CenterHorizontally))
                            }
                            Step.CODE -> {
                                ConnectedChip(host) { back() }
                                Eyebrow("Pairing code")
                                CodeField(code) { new -> code = new; if (new.length == 6) claim() }
                                Text("In Marquee on your computer or phone browser: Settings › Devices › Pair a new device. Codes last five minutes and work once.", style = T.caption, color = C.inkMuted)
                                DeviceNameField(deviceName) { deviceName = it }
                                PrimaryButton("Pair this device", { claim() }, Modifier.padding(top = 4.dp).testTag("pairing.claim"), enabled = code.length == 6, busy = busy)
                                QuietButton("Sign in with a password instead", { error = null; step = Step.SIGN_IN }, Modifier.align(Alignment.CenterHorizontally))
                            }
                        }
                    }
                }

                error?.let {
                    Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Filled.Warning, null, tint = C.velvet, modifier = Modifier.size(18.dp))
                        Text(it, style = T.sub, color = C.velvet)
                    }
                }
                if (step == Step.ADDRESS) session.signedOutReason?.let {
                    Text(it, style = T.caption, color = C.inkMuted, modifier = Modifier.padding(top = 18.dp))
                }
            }
            Spacer(Modifier.weight(1f).heightIn(min = 40.dp))
            Text(
                "Marquee only ever talks to the server you pair it with. No analytics, no crash reporting, nothing sent anywhere else.",
                style = T.caption, color = C.inkMuted, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 400.dp).padding(vertical = 30.dp),
            )
        }
    }
}

@Composable
private fun MqField(
    value: String, onChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier,
    secret: Boolean = false, keyboard: KeyboardOptions = KeyboardOptions.Default, onGo: (() -> Unit)? = null,
) {
    OutlinedTextField(
        value, onChange, modifier.fillMaxWidth(), singleLine = true, textStyle = T.body.copy(color = C.ink),
        placeholder = { Text(placeholder, style = T.body, color = C.inkMuted) },
        visualTransformation = if (secret) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        keyboardOptions = keyboard, keyboardActions = KeyboardActions(onGo = { onGo?.invoke() }, onDone = { onGo?.invoke() }),
        shape = RoundedCornerShape(11.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedContainerColor = C.panel, unfocusedContainerColor = C.panel, focusedBorderColor = C.brassDim,
            unfocusedBorderColor = C.hairline, cursorColor = C.brass,
        ),
    )
}

@Composable
private fun DeviceNameField(value: String, onChange: (String) -> Unit) {
    Column(Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Eyebrow("Name this device")
        MqField(value, onChange, "Android", keyboard = KeyboardOptions(imeAction = ImeAction.Done))
        Text("Shown in your server's device list, so you know which one to unpair later.", style = T.caption, color = C.inkMuted)
    }
}

@Composable
private fun ConnectedChip(host: String, change: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(C.brassSoft).padding(horizontal = 14.dp, vertical = 11.dp)
            .semantics(mergeDescendants = true) { contentDescription = "Connected to $host" },
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Filled.Verified, null, tint = C.brass, modifier = Modifier.size(18.dp))
        Text(host, style = T.sub, color = C.ink, maxLines = 1, overflow = TextOverflow.MiddleEllipsis, modifier = Modifier.weight(1f))
        Text("Change", style = T.caption, color = C.brass, modifier = Modifier.clip(RoundedCornerShape(6.dp)).clickable(onClick = change).padding(4.dp))
    }
}

@Composable
private fun MethodCard(title: String, detail: String, icon: androidx.compose.ui.graphics.vector.ImageVector, emphasised: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(C.panel).border(1.dp, if (emphasised) C.brassDim else C.hairline, shape)
            .clickable(onClick = onClick).padding(15.dp),
        horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Icon(icon, null, tint = if (emphasised) C.brass else C.inkSoft, modifier = Modifier.size(28.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = T.headline, color = C.ink)
            Text(detail, style = T.caption, color = C.inkMuted)
        }
        Icon(Icons.Filled.ChevronRight, null, tint = C.inkMuted, modifier = Modifier.padding(top = 2.dp).size(18.dp))
    }
}

/** Six digits, spaced out, backed by one text field so paste and autofill behave. */
@Composable
private fun CodeField(code: String, onChange: (String) -> Unit) {
    val fr = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { fr.requestFocus() } }
    BasicTextField(
        value = code,
        onValueChange = { onChange(it.filter(Char::isDigit).take(6)) },
        modifier = Modifier.fillMaxWidth().focusRequester(fr).testTag("pairing.code"),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
        singleLine = true,
        decorationBox = { _ ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                repeat(6) { i ->
                    val ch = code.getOrNull(i)
                    val active = i == code.length
                    Box(
                        Modifier.weight(1f).heightIn(min = 56.dp).clip(RoundedCornerShape(11.dp)).background(C.panel)
                            .border(1.dp, if (active) C.brass else if (ch != null) C.brassDim else C.hairline, RoundedCornerShape(11.dp)),
                        contentAlignment = Alignment.Center,
                    ) { Text(ch?.toString() ?: "", style = T.wordmark(26f), color = C.brass) }
                }
            }
        },
    )
}
