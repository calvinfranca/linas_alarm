package com.example.linas_alarm.alarm

import android.content.Context
import org.json.JSONArray
import kotlin.random.Random

object AlarmStorage {

    private const val PREFS = "alarm_music_pool"
    private const val KEY_PREFIX = "pool_" // pool_<groupId>

    fun pickNextNoRepeat(
        context: Context,
        groupId: String,
        pathsJson: String
    ): String? {
        val all = jsonToList(pathsJson)
        if (all.isEmpty()) {
            clearPool(context, groupId)
            return null
        }

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = KEY_PREFIX + groupId

        // pool atual salvo (restantes)
        val savedPoolJson = prefs.getString(key, null)
        var pool = if (savedPoolJson.isNullOrBlank()) {
            all.toMutableList()
        } else {
            val saved = jsonToList(savedPoolJson).toMutableList()

            // Se a lista do grupo mudou, sincroniza:
            // - remove itens que não existem mais
            // - adiciona novos itens que não estavam no pool
            saved.retainAll(all)
            val missing = all.filter { it !in saved }
            saved.addAll(missing)

            if (saved.isEmpty()) all.toMutableList() else saved
        }

        val idx = Random.nextInt(pool.size)
        val picked = pool.removeAt(idx)

        // salva pool atualizado
        prefs.edit().putString(key, listToJson(pool)).apply()

        return picked
    }

    fun clearPool(context: Context, groupId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_PREFIX + groupId).apply()
    }

    private fun jsonToList(json: String): List<String> {
        val arr = JSONArray(json)
        val out = ArrayList<String>(arr.length())
        for (i in 0 until arr.length()) {
            val s = arr.optString(i, null)
            if (!s.isNullOrBlank()) out.add(s)
        }
        return out
    }

    private fun listToJson(list: List<String>): String {
        val arr = JSONArray()
        for (s in list) arr.put(s)
        return arr.toString()
    }
}
