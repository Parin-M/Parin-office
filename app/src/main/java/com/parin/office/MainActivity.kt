package com.parin.office
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import com.parin.office.ui.ParinOfficeApp
class MainActivity:ComponentActivity(){
 override fun onCreate(state:Bundle?){super.onCreate(state);setContent{ParinOfficeApp(intent?.data)}}
 fun setLocale(tag:String){AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tag))}
 fun openExternal(uri:Uri){runCatching{startActivity(Intent(Intent.ACTION_VIEW,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))}}
}
