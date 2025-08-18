defmodule Aesir.ZoneServer.Scripting.ROFunctions do
  @moduledoc """
  Ragnarok Online specific functions exposed to Lua scripts.
  Uses Lua.API for clean integration with the Lua VM.
  """
  use Lua.API

  require Logger

  deflua _get_player(), state do
    {[nil], state}
  end

  # ============= Player Functions =============

  deflua bonus(stat, value), state do
    Logger.debug("bonus(#{stat}, #{value})")
    {[true], state}
  end

  deflua bonus2(stat, val1, val2), state do
    Logger.debug("bonus2(#{stat}, #{val1}, #{val2})")
    {[true], state}
  end

  deflua bonus3(stat, val1, val2, val3), state do
    Logger.debug("bonus3(#{stat}, #{val1}, #{val2}, #{val3})")
    {[true], state}
  end

  deflua bonus4(stat, val1, val2, val3, val4), state do
    Logger.debug("bonus4(#{stat}, #{val1}, #{val2}, #{val3}, #{val4})")
    {[true], state}
  end

  deflua bonus5(stat, val1, val2, val3, val4, val5), state do
    Logger.debug("bonus5(#{stat}, #{val1}, #{val2}, #{val3}, #{val4}, #{val5})")
    {[true], state}
  end

  # ============= Status Effects =============

  deflua sc_start(status_id, duration, val1), state do
    Logger.debug("sc_start(#{status_id}, #{duration}, #{val1})")
    {[true], state}
  end

  deflua sc_start2(status_id, duration, val1, rate), state do
    Logger.debug("sc_start2(#{status_id}, #{duration}, #{val1}, #{rate})")
    {[true], state}
  end

  deflua sc_start4(status_id, duration, val1, val2, val3, val4), state do
    Logger.debug("sc_start4(#{status_id}, #{duration}, #{val1}, #{val2}, #{val3}, #{val4})")
    {[true], state}
  end

  deflua sc_end(status_id), state do
    Logger.debug("sc_end(#{status_id})")
    {[true], state}
  end

  # ============= Healing =============

  deflua heal(hp, sp), state do
    Logger.debug("heal(#{hp}, #{sp})")
    {[true], state}
  end

  deflua percentheal(hp_percent, sp_percent), state do
    Logger.debug("percentheal(#{hp_percent}, #{sp_percent})")
    {[true], state}
  end

  deflua itemheal(hp, sp), state do
    Logger.debug("itemheal(#{hp}, #{sp})")
    {[true], state}
  end

  # ============= Character Info =============

  deflua getcharid(type), state do
    Logger.debug("getcharid(#{type})")
    player = Lua.get_private!(state, :current_player)

    id =
      case type do
        0 -> player[:char_id] || 0
        1 -> player[:party_id] || 0
        2 -> player[:guild_id] || 0
        3 -> player[:account_id] || 0
        _ -> 0
      end

    {[id], state}
  end

  deflua getbasejob(), state do
    Logger.debug("getbasejob()")

    player = Lua.get_private!(state, :current_player)

    {[player[:job]], state}
  end

  deflua getjoblevel(), state do
    Logger.debug("getjoblevel()")

    player = Lua.get_private!(state, :current_player)

    {[player[:job_level]], state}
  end

  deflua getbaselevel(), state do
    Logger.debug("getbaselevel()")

    player = Lua.get_private!(state, :current_player)

    {[player[:base_level]], state}
  end

  deflua getskilllv(skill_id), state do
    Logger.debug("getskilllv(#{skill_id})")

    {[10], state}
  end

  # ============= Character Modification =============

  deflua jobchange(job_id), state do
    Logger.debug("jobchange(#{job_id})")
    {[true], state}
  end

  deflua changesex(), state do
    Logger.debug("changesex()")
    {[true], state}
  end

  deflua resetstatus(), state do
    _player = Lua.get_private!(state, :current_player)
    Logger.debug("resetstatus()")
    {[true], state}
  end

  deflua resetskill(), state do
    Logger.debug("resetskill()")
    {[true], state}
  end

  # ============= Item Functions =============

  deflua getitem(item_id, amount \\ 1), state do
    Logger.debug("getitem(#{item_id}, #{amount})")

    {[true], state}
  end

  deflua getitem2(item_id, amount, identify, refine, attribute, c1, c2, c3, c4), state do
    Logger.debug(
      "getitem2(#{item_id}, #{amount}, #{identify}, #{refine}, #{attribute}, #{c1}, #{c2}, #{c3}, #{c4})"
    )

    {[true], state}
  end

  deflua delitem(item_id, amount \\ 1), state do
    Logger.debug("delitem(#{item_id}, #{amount})")
    {[true], state}
  end

  deflua countitem(item_id), state do
    Logger.debug("countitem(#{item_id})")
    {[5], state}
  end

  deflua checkweight(item_id, amount), state do
    Logger.debug("checkweight(#{item_id}, #{amount})")
    {[1], state}
  end

  # ============= Equipment Functions =============

  deflua getequipid(slot), state do
    Logger.debug("getequipid(#{slot})")
    {[1101], state}
  end

  deflua getequipname(slot), state do
    Logger.debug("getequipname(#{slot})")
    {["Sword"], state}
  end

  deflua getequiprefinerycnt(slot), state do
    Logger.debug("getequiprefinerycnt(#{slot})")
    {[7], state}
  end

  deflua getequipweaponlv(slot), state do
    Logger.debug("getequipweaponlv(#{slot})")
    {[3], state}
  end

  deflua getequippercentrefinery(slot), state do
    Logger.debug("getequippercentrefinery(#{slot})")
    {[60], state}
  end

  # TODO
  deflua getrefine(), state do
    Logger.debug("getrefine()")
    {0, state}
  end

  deflua successrefitem(slot), state do
    Logger.debug("successrefitem(#{slot})")
    {[true], state}
  end

  deflua failedrefitem(slot), state do
    Logger.debug("failedrefitem(#{slot})")
    {[true], state}
  end

  # ============= Combat Functions =============

  deflua autobonus(bonus_script, rate, duration), state do
    Logger.debug("autobonus(#{bonus_script}, #{rate}, #{duration})")
    {[true], state}
  end

  deflua autobonus2(bonus_script, rate, duration, flag), state do
    Logger.debug("autobonus2(#{bonus_script}, #{rate}, #{duration}, #{flag})")
    {[true], state}
  end

  deflua autobonus3(bonus_script, rate, duration, flag, target), state do
    Logger.debug("autobonus3(#{bonus_script}, #{rate}, #{duration}, #{flag}, #{target})")
    {[true], state}
  end

  deflua skill(skill_id, level), state do
    Logger.debug("skill(#{skill_id}, #{level})")
    {[true], state}
  end

  deflua addtoskill(skill_id, level), state do
    Logger.debug("addtoskill(#{skill_id}, #{level})")
    {[true], state}
  end

  deflua getstatus(status_id), state do
    Logger.debug("getstatus(#{status_id})")
    {[0], state}
  end

  deflua setoption(option), state do
    Logger.debug("setoption(#{option})")
    {[true], state}
  end

  deflua checkoption(option), state do
    Logger.debug("checkoption(#{option})")
    {[0], state}
  end

  # ============= Utility Functions =============

  deflua rand(min, max), state do
    Logger.debug("rand(#{min}, #{max})")
    value = :rand.uniform(max - min + 1) + min - 1
    {[value], state}
  end

  deflua mes(text), state do
    Logger.debug("mes(#{text})")
    {[true], state}
  end

  deflua select(options), state do
    Logger.debug("select(#{options})")
    {[1], state}
  end

  deflua prompt(text), state do
    Logger.debug("prompt(#{text})")
    {["user_input"], state}
  end

  deflua close(), state do
    Logger.debug("close()")
    {[true], state}
  end

  deflua next(), state do
    Logger.debug("next()")
    {[true], state}
  end

  # ============= World Functions =============

  deflua warp(map_name, x, y), state do
    Logger.debug("warp(#{map_name}, #{x}, #{y})")
    {[true], state}
  end

  deflua areawarp(map, x1, y1, x2, y2, target_map, tx, ty), state do
    Logger.debug("areawarp(#{map}, #{x1}, #{y1}, #{x2}, #{y2}, #{target_map}, #{tx}, #{ty})")
    {[true], state}
  end

  deflua save(map_name, x, y), state do
    Logger.debug("save(#{map_name}, #{x}, #{y})")
    {[true], state}
  end

  deflua savepoint(map_name, x, y), state do
    Logger.debug("savepoint(#{map_name}, #{x}, #{y})")
    {[true], state}
  end

  # ============= Time Functions =============

  deflua gettimetick(type \\ 0), state do
    Logger.debug("gettimetick(#{type})")
    # Return current tick based on type
    tick =
      case type do
        0 -> System.system_time(:millisecond)
        1 -> System.system_time(:second)
        2 -> System.system_time(:millisecond)
        _ -> 0
      end

    {[tick], state}
  end

  deflua gettime(type), state do
    Logger.debug("gettime(#{type})")

    # Return time component based on type
    # 1=sec, 2=min, 3=hour, 4=weekday, 5=day, 6=month, 7=year
    now = DateTime.utc_now()

    value =
      case type do
        1 -> now.second
        2 -> now.minute
        3 -> now.hour
        4 -> Date.day_of_week(now)
        5 -> now.day
        6 -> now.month
        7 -> now.year
        _ -> 0
      end

    {[value], state}
  end

  # ============= Announcement Functions =============

  deflua announce(message, flag \\ 0), state do
    Logger.debug("announce(#{message}, #{flag})")
    {[true], state}
  end

  deflua mapannounce(map_name, message, flag \\ 0), state do
    Logger.debug("mapannounce(#{map_name}, #{message}, #{flag})")
    {[true], state}
  end

  deflua getusers(type \\ 0), state do
    Logger.debug("getusers(#{type})")
    {[100], state}
  end

  deflua getmapusers(map_name), state do
    Logger.debug("getmapusers(#{map_name})")
    {[10], state}
  end
end
