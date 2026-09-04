defmodule Aesir.ZoneServer.Script.Dsl do
  @moduledoc """
  The import surface of the item/NPC scripting DSL: every effect and read
  primitive a script uses, delegated per name/arity to its domain module.

  Functions take the script `Ctx` first so they can be `import`ed into a
  generated module or called directly from an NPC module. They split into two
  groups:

  - **Effects** (`(ctx, args) -> ctx`) short-circuit when `ctx.status` is
    already an error, perform their subsystem side effect, and halt the
    context with `Ctx.halt/2` on a subsystem error.
  - **Reads** (`(ctx) -> value`) pull a value out of `ctx.game_state` and
    ignore status.

  Implementations live in the domain modules under `Dsl.`:

  - `Dsl.Dialog` — mes/next/select/input/close, sleep2, progressbar
  - `Dsl.PlayerEffects` — heal/sc_*, homunculus staging, exp, job, mounts,
    savepoint, storage, attachrid
  - `Dsl.Skills` — npcskill, skilleffect, itemskill, skill grants/reset
  - `Dsl.Visuals` — looks, effects, viewpoint, questinfo, cutin, sound,
    navigation, emotes, nude
  - `Dsl.Announce` — announce/broadcast family, dispbottom, logmes
  - `Dsl.Movement` — warp, areawarp, warpchar
  - `Dsl.Items` — zeny, item grants/removal, groups, repair, refine,
    checkweight
  - `Dsl.Quest` — quest log ops
  - `Dsl.Variables` — char/temp/server/account/npc/local vars, getd/setd
  - `Dsl.NpcControl` — mob summons/kills, cells, NPC events/timers/display,
    waiting rooms, hide/cloak
  - `Dsl.Reads` — pure reads: identity, vitals, equip/item inspection, party,
    NPC info, time, string helpers

  Shared non-public plumbing lives in `Dsl.Internal`. Adding a buildin means
  implementing it in a domain module, delegating it here, and updating the
  export snapshot fixture (`test/support/fixtures/dsl_exports.snapshot`).
  """

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Announce
  alias Aesir.ZoneServer.Script.Dsl.Dialog
  alias Aesir.ZoneServer.Script.Dsl.Items
  alias Aesir.ZoneServer.Script.Dsl.Movement
  alias Aesir.ZoneServer.Script.Dsl.NpcControl
  alias Aesir.ZoneServer.Script.Dsl.PlayerEffects
  alias Aesir.ZoneServer.Script.Dsl.Quest
  alias Aesir.ZoneServer.Script.Dsl.Reads
  alias Aesir.ZoneServer.Script.Dsl.Skills
  alias Aesir.ZoneServer.Script.Dsl.Variables
  alias Aesir.ZoneServer.Script.Dsl.Visuals
  alias Aesir.ZoneServer.Script.Todo

  # -- PlayerEffects (Dsl.PlayerEffects) ---------------------------------------

  defdelegate homevolution(ctx), to: PlayerEffects
  defdelegate add_homunculus_intimacy(ctx, amount), to: PlayerEffects
  defdelegate heal(ctx, opts), to: PlayerEffects
  defdelegate percent_heal(ctx, opts), to: PlayerEffects
  defdelegate sc_start(ctx, status, duration_ms, val), to: PlayerEffects
  defdelegate sc_end(ctx, status), to: PlayerEffects
  defdelegate cure(ctx, status), to: PlayerEffects
  defdelegate savepoint(ctx, map, x, y), to: PlayerEffects
  defdelegate getexp(ctx, base_exp, job_exp), to: PlayerEffects
  defdelegate resetlvl(ctx, type), to: PlayerEffects
  defdelegate jobchange(ctx, job), to: PlayerEffects
  defdelegate openstorage(ctx), to: PlayerEffects
  defdelegate guildopenstorage(ctx), to: PlayerEffects
  defdelegate setcart(ctx), to: PlayerEffects
  defdelegate setcart(ctx, type), to: PlayerEffects
  defdelegate set_riding(ctx, riding?), to: PlayerEffects
  defdelegate setfalcon(ctx, flag), to: PlayerEffects
  defdelegate attachrid(ctx, account_id), to: PlayerEffects
  defdelegate attachrid(ctx, account_id, force), to: PlayerEffects

  # -- Dialog (Dsl.Dialog) -----------------------------------------------------

  defdelegate mes(ctx, text), to: Dialog
  defdelegate next(ctx), to: Dialog
  defdelegate select(ctx, options), to: Dialog
  defdelegate input(ctx, kind), to: Dialog
  defdelegate close(ctx), to: Dialog
  defdelegate sleep2(ctx, ms), to: Dialog
  defdelegate progressbar(ctx, color, seconds), to: Dialog

  # -- Skills (Dsl.Skills) -----------------------------------------------------

  defdelegate npcskill(ctx, skill, level, stat_point, npc_level), to: Skills
  defdelegate skilleffect(ctx, skill, level), to: Skills
  defdelegate itemskill(ctx, skill_id_or_name, opts), to: Skills
  defdelegate skill(ctx, skill_id_or_name, level, flag), to: Skills
  defdelegate reset_skills(ctx), to: Skills
  defdelegate basicskillcheck(ctx), to: Skills

  # -- Visuals (Dsl.Visuals) ---------------------------------------------------

  defdelegate getlook(ctx, type), to: Visuals
  defdelegate setlook(ctx, type, value), to: Visuals
  defdelegate specialeffect(ctx, effect), to: Visuals
  defdelegate specialeffect2(ctx, effect), to: Visuals
  defdelegate viewpoint(ctx, type, x, y, id, color), to: Visuals
  defdelegate questinfo(ctx, icon), to: Visuals
  defdelegate questinfo(ctx, icon, color), to: Visuals
  defdelegate questinfo(ctx, icon, color, condition), to: Visuals
  defdelegate cutin(ctx, image, type), to: Visuals
  defdelegate soundeffect(ctx, name, type), to: Visuals
  defdelegate soundeffectall(ctx, name, type), to: Visuals
  defdelegate navigateto(ctx, map, x, y, flag, hide_window, monster_id), to: Visuals
  defdelegate emotion(ctx, emote), to: Visuals
  defdelegate nude(ctx), to: Visuals

  # -- Announce (Dsl.Announce) -----------------------------------------------

  defdelegate announce(ctx, text, flag), to: Announce
  defdelegate announce(ctx, text, flag, color), to: Announce
  defdelegate mapannounce(ctx, map, text, flag), to: Announce
  defdelegate mapannounce(ctx, map, text, flag, color), to: Announce
  defdelegate areaannounce(ctx, map, x0, y0, x1, y1, text, flag), to: Announce

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defdelegate areaannounce(ctx, map, x0, y0, x1, y1, text, flag, color), to: Announce
  defdelegate broadcast(ctx, text, flag), to: Announce
  defdelegate broadcast(ctx, text, flag, color), to: Announce
  defdelegate dispbottom(ctx, text), to: Announce
  defdelegate dispbottom(ctx, text, color), to: Announce
  defdelegate logmes(ctx, message), to: Announce

  # -- Movement (Dsl.Movement) -----------------------------------------------

  defdelegate warp(ctx, target), to: Movement
  defdelegate warp(ctx, map, x, y), to: Movement
  defdelegate mapwarp(ctx, from_map, to_map, x, y), to: Movement
  defdelegate mapwarp(ctx, from_map, to_map, x, y, type), to: Movement
  defdelegate mapwarp(ctx, from_map, to_map, x, y, type, id), to: Movement
  defdelegate areawarp(ctx, from_map, x1, y1, x2, y2, to_map, x3, y3), to: Movement
  defdelegate areawarp(ctx, from_map, x1, y1, x2, y2, to_map, x3, y3, x4, y4), to: Movement
  defdelegate warpchar(ctx, map, x, y), to: Movement
  defdelegate warpchar(ctx, map, x, y, char_id), to: Movement

  # -- Items (Dsl.Items) -------------------------------------------------------

  defdelegate zeny(ctx), to: Items
  defdelegate pay_zeny(ctx, amount), to: Items
  defdelegate credit_zeny(ctx, amount), to: Items
  defdelegate give_item(ctx, item_id, qty), to: Items
  defdelegate get_group_item(ctx, group_key), to: Items
  defdelegate get_rand_group_item(ctx, group_key, qty, sub), to: Items
  defdelegate group_rand_item(ctx, group_key, sub), to: Items
  defdelegate commit_grants(ctx, grants), to: Items
  defdelegate get_named_item(ctx, item_id, target), to: Items
  defdelegate give_item_rental(ctx, item_id, seconds), to: Items
  defdelegate give_item_rental(ctx, item_id, seconds, opts), to: Items
  defdelegate give_item_bound(ctx, item_id, qty, bound), to: Items
  defdelegate delitem(ctx, item_id, qty), to: Items
  defdelegate delequip(ctx, slot), to: Items
  defdelegate successrefitem(ctx, slot), to: Items
  defdelegate successrefitem(ctx, slot, up), to: Items
  defdelegate failedrefitem(ctx, slot), to: Items
  defdelegate disable_items(ctx), to: Items
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defdelegate getitem2(ctx, item, qty, identify, refine, attr, card1, card2, card3, card4),
    to: Items

  defdelegate consumeitem(ctx, item_id), to: Items
  defdelegate repair(ctx, index), to: Items
  defdelegate repairall(ctx), to: Items
  defdelegate getbrokenid(ctx, n), to: Items
  defdelegate count_item(ctx, item_id), to: Items
  defdelegate refine_targets(ctx), to: Items
  defdelegate refinable?(ctx, index), to: Items
  defdelegate refine_rate(ctx, index, cost_type), to: Items
  defdelegate refine_cost(ctx, index, cost_type), to: Items
  defdelegate refine(ctx, index, cost_type), to: Items
  defdelegate refine(ctx, index, cost_type, use_blessing?), to: Items
  defdelegate checkweight(ctx, items), to: Items

  # -- Quest (Dsl.Quest) -----------------------------------------------------

  defdelegate setquest(ctx, quest_id), to: Quest
  defdelegate erasequest(ctx, quest_id), to: Quest
  defdelegate completequest(ctx, quest_id), to: Quest
  defdelegate changequest(ctx, old_id, new_id), to: Quest
  defdelegate checkquest(ctx, quest_id), to: Quest
  defdelegate checkquest(ctx, quest_id, mode), to: Quest
  defdelegate questprogress(ctx, quest_id), to: Quest
  defdelegate questprogress(ctx, quest_id, mode), to: Quest
  defdelegate isbegin_quest(ctx, quest_id), to: Quest

  # -- Variables (Dsl.Variables) -----------------------------------------------

  defdelegate get_char_var(ctx, key), to: Variables
  defdelegate get_char_var(ctx, key, default), to: Variables
  defdelegate set_char_var(ctx, key, value), to: Variables
  defdelegate get_temp_var(ctx, key), to: Variables
  defdelegate get_temp_var(ctx, key, default), to: Variables
  defdelegate set_temp_var(ctx, key, value), to: Variables
  defdelegate get_server_var(ctx, name), to: Variables
  defdelegate get_server_var(ctx, name, default), to: Variables
  defdelegate set_server_var(ctx, name, value), to: Variables
  defdelegate get_server_temp_var(ctx, name), to: Variables
  defdelegate get_server_temp_var(ctx, name, default), to: Variables
  defdelegate set_server_temp_var(ctx, name, value), to: Variables
  defdelegate get_account_var(ctx, name), to: Variables
  defdelegate get_account_var(ctx, name, default), to: Variables
  defdelegate set_account_var(ctx, name, value), to: Variables
  defdelegate get_npc_var(ctx, name), to: Variables
  defdelegate get_npc_var(ctx, name, default), to: Variables
  defdelegate set_npc_var(ctx, name, value), to: Variables
  defdelegate get_npc_var_of(ctx, name, npc_name), to: Variables
  defdelegate get_npc_var_of(ctx, name, npc_name, default), to: Variables
  defdelegate set_npc_var_of(ctx, name, npc_name, value), to: Variables
  defdelegate getd(ctx, name), to: Variables
  defdelegate setd(ctx, name, value), to: Variables
  defdelegate set_local(ctx, key, value), to: Variables
  defdelegate get_local(ctx, key), to: Variables
  defdelegate get_local(ctx, key, default), to: Variables

  @doc """
  Stub for an rAthena buildin with no Aesir implementation yet.

  Transpiled scripts call this in place of the unsupported command; reaching it
  raises `NotImplementedError` naming the buildin, which ends the interaction
  (a supervised Task) without harming the player session. The raise is
  indirect (see `Todo`) so generated `ctx = todo(...)` lines do not trip the
  compiler's no_return inference.
  """
  @spec todo(Ctx.t(), atom(), [term()]) :: Ctx.t()
  def todo(%Ctx{} = ctx, buildin, args) do
    Todo.call!(buildin, args)
    ctx
  end

  # -- Reads (Dsl.Reads) -------------------------------------------------------

  defdelegate checkfalcon(ctx), to: Reads
  defdelegate ismounting(ctx), to: Reads
  defdelegate checkcart(ctx), to: Reads
  defdelegate base_level(ctx), to: Reads
  defdelegate job_level(ctx), to: Reads
  defdelegate class(ctx), to: Reads
  defdelegate base_class(ctx), to: Reads
  defdelegate base_job(ctx), to: Reads
  defdelegate can_change_job?(ctx), to: Reads
  defdelegate getskilllv(ctx, skill), to: Reads
  defdelegate char_name(ctx, type), to: Reads
  defdelegate char_name(ctx, type, char_id), to: Reads
  defdelegate job_name(ctx, job), to: Reads
  defdelegate eaclass(ctx), to: Reads
  defdelegate eaclass(ctx, job), to: Reads
  defdelegate roclass(ctx, mapid), to: Reads
  defdelegate roclass(ctx, mapid, sex), to: Reads
  defdelegate sex(ctx), to: Reads
  defdelegate hp(ctx), to: Reads
  defdelegate sp(ctx), to: Reads
  defdelegate max_hp(ctx), to: Reads
  defdelegate weight(ctx), to: Reads
  defdelegate position(ctx), to: Reads
  defdelegate is_equipped(ctx, item_id), to: Reads
  defdelegate getequipid(ctx, slot), to: Reads
  defdelegate getequipcardid(ctx, equip_slot, card_slot), to: Reads
  defdelegate getequipisequiped(ctx, slot), to: Reads
  defdelegate getequiprefinerycnt(ctx, slot), to: Reads
  defdelegate getequipname(ctx, slot), to: Reads
  defdelegate equip_position_name(ctx, index), to: Reads
  defdelegate getequipweaponlv(ctx, slot), to: Reads
  defdelegate getequiparmorlv(ctx, slot), to: Reads
  defdelegate getequipisenableref(ctx, slot), to: Reads
  defdelegate getequippercentrefinery(ctx, slot), to: Reads
  defdelegate getequippercentrefinery(ctx, slot, enriched), to: Reads
  defdelegate getequiprefinecost(ctx, slot, type, info), to: Reads
  defdelegate isequippedcnt(ctx, item_ids), to: Reads
  defdelegate getiteminfo(ctx, item, type), to: Reads
  defdelegate getmonsterinfo(ctx, mob, type), to: Reads
  defdelegate num_suffix(ctx, n), to: Reads
  defdelegate insert_comma(ctx, value), to: Reads
  defdelegate getpartnerid(ctx), to: Reads
  defdelegate checkre(ctx, type), to: Reads
  defdelegate vip_status(ctx, type), to: Reads
  defdelegate gettimetick(ctx, type), to: Reads
  defdelegate gettime(ctx, type), to: Reads
  defdelegate getnpcid(ctx), to: Reads
  defdelegate getnpcid(ctx, name), to: Reads
  defdelegate playerattached(ctx), to: Reads
  defdelegate getcharid(ctx, type), to: Reads
  defdelegate getguildname(ctx, guild_id), to: Reads
  defdelegate party_leader?(ctx), to: Reads
  defdelegate party_leader?(ctx, party_id), to: Reads
  defdelegate strnpcinfo(ctx, type), to: Reads

  # -- NpcControl (Dsl.NpcControl) ---------------------------------------------

  defdelegate summon_mob(ctx, opts), to: NpcControl
  defdelegate summon_random_mob(ctx, opts), to: NpcControl
  defdelegate summon_mob_area(ctx, opts), to: NpcControl
  defdelegate killmonster(ctx, map, event), to: NpcControl
  defdelegate killmonsterall(ctx, map), to: NpcControl
  defdelegate setcell(ctx, map, x1, y1, x2, y2, type, flag), to: NpcControl
  defdelegate mobcount(ctx, map, event), to: NpcControl
  defdelegate getmapusers(ctx, map_name), to: NpcControl

  defdelegate donpcevent(ctx, ref), to: NpcControl
  defdelegate doevent(ctx, ref), to: NpcControl
  defdelegate initnpctimer(ctx), to: NpcControl
  defdelegate initnpctimer(ctx, name), to: NpcControl
  defdelegate stopnpctimer(ctx), to: NpcControl
  defdelegate stopnpctimer(ctx, name), to: NpcControl
  defdelegate getnpctimer(ctx), to: NpcControl
  defdelegate getnpctimer(ctx, name), to: NpcControl
  defdelegate npctalk(ctx, text), to: NpcControl
  defdelegate npctalk(ctx, text, opts), to: NpcControl
  defdelegate set_npc_display(ctx, opts), to: NpcControl
  defdelegate enablenpc(ctx), to: NpcControl
  defdelegate enablenpc(ctx, name), to: NpcControl
  defdelegate disablenpc(ctx), to: NpcControl
  defdelegate disablenpc(ctx, name), to: NpcControl
  defdelegate waitingroom(ctx, title, limit), to: NpcControl
  defdelegate waitingroom(ctx, title, limit, event_ref), to: NpcControl
  defdelegate waitingroom(ctx, title, limit, event_ref, trigger), to: NpcControl
  defdelegate waitingroom(ctx, title, limit, event_ref, trigger, zeny), to: NpcControl
  defdelegate waitingroom(ctx, title, limit, event_ref, trigger, zeny, min_lvl), to: NpcControl

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defdelegate waitingroom(ctx, title, limit, event_ref, trigger, zeny, min_lvl, max_lvl),
    to: NpcControl

  defdelegate delwaitingroom(ctx), to: NpcControl
  defdelegate delwaitingroom(ctx, name), to: NpcControl
  defdelegate enablewaitingroomevent(ctx), to: NpcControl
  defdelegate enablewaitingroomevent(ctx, name), to: NpcControl
  defdelegate disablewaitingroomevent(ctx), to: NpcControl
  defdelegate disablewaitingroomevent(ctx, name), to: NpcControl
  defdelegate warpwaitingpc(ctx, map, x, y), to: NpcControl
  defdelegate warpwaitingpc(ctx, map, x, y, count), to: NpcControl
  defdelegate waitingroomkick(ctx, npc_name, char_name), to: NpcControl
  defdelegate kickwaitingroomall(ctx), to: NpcControl
  defdelegate kickwaitingroomall(ctx, name), to: NpcControl
  defdelegate getwaitingroomusers(ctx), to: NpcControl
  defdelegate getwaitingroomusers(ctx, name), to: NpcControl
  defdelegate getwaitingroomstate(ctx, type), to: NpcControl
  defdelegate getwaitingroomstate(ctx, type, npc_name), to: NpcControl
  defdelegate hideonnpc(ctx), to: NpcControl
  defdelegate hideonnpc(ctx, name), to: NpcControl
  defdelegate hideoffnpc(ctx), to: NpcControl
  defdelegate hideoffnpc(ctx, name), to: NpcControl
  defdelegate cloakonnpc(ctx), to: NpcControl
  defdelegate cloakonnpc(ctx, name), to: NpcControl
  defdelegate cloakoffnpcself(ctx), to: NpcControl
  defdelegate cloakoffnpcself(ctx, name), to: NpcControl
end
