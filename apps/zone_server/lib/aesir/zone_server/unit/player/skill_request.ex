defmodule Aesir.ZoneServer.Unit.Player.SkillRequest do
  @moduledoc """
  The checks a player's skill request passes before its cast is attempted, in
  the order the client request handlers run them, and the reply each refusal
  sends.

  A request aimed at a unit (`targeted/5`) is refused, in order: for a ground,
  passive or unknown skill; while an NPC dialog holds the player, unless its
  script lets items be used, no work flag is held and the skill targets the
  user (renewal shows the busy notice, pre-renewal stays silent); while a
  trade, chat room, vending stall, storage window or a body state other than
  Burning holds the player, unless a storage window is open and the skill
  targets the user; while sitting; by `not_ok/3` (`UseRestrictions.check/4`);
  while casting, unless the
  skill is Cast Cancel; while the act delay runs, unless the skill comes from
  an item; in pre-renewal, while Basilica holds the player, unless the caster
  ends its own Basilica; and while a skill menu other than Autospell is open.
  Every refusal but `not_ok/3`'s and the act delay's is silent. A skill that
  targets the user is then aimed at the user whatever the client named.

  A request aimed at the ground (`ground/5`) is refused only for a skill that
  is not a ground skill, while a work flag is held (renewal shows the busy
  notice), by `not_ok/3`, for a skill that asks for text while the player sits
  (a generic failure), while casting, while the act delay runs (unless the
  skill comes from an item), by Basilica and by an open menu. Dialogs,
  trades, vending stalls, storage windows and body states do not refuse it.

  A request that passes ends the player's invincibility, except a targeted
  item skill aimed at the user. An item skill then runs at the item's level;
  any other request clears a pending item skill and runs at the requested
  level capped by the player's own level (`Caster.Player.request_level/3` for
  a targeted request, the player's level for a ground one), and is dropped
  without a reply when that is 0. A ground request asking for level 0 is
  dropped the same way.

  An act delay or cooldown refusal is reported only to a player who turned
  delay notices on (`@showdelay`).
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.UseRestrictions
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @vending 41
  @cast_cancel 275
  @autospell 279
  @basilica 362
  @combo_skills [272, 273, 371, 372]
  @burning 7

  @typedoc "The reply a refusal sends (`UseRestrictions.reply/0`)."
  @type reply :: UseRestrictions.reply()

  @typedoc """
  A request that passed: whether it comes from a pending item skill, the level
  it runs at (`0` drops it), its target, whether it ends the invincibility and
  whether it clears a pending item skill.
  """
  @type proceed :: %{
          origin: :skill | :item,
          level: non_neg_integer(),
          target: term(),
          ends_invincibility?: boolean(),
          clears_item_skill?: boolean()
        }

  @type decision :: {:refuse, reply()} | {:use, proceed()}

  @doc "Decides a request to use `skill_id` on the unit `target` at `requested`."
  @spec targeted(SessionState.t(), integer(), non_neg_integer(), term(), integer()) :: decision()
  def targeted(state, skill_id, requested, target, now) do
    inf = inf(skill_id)

    with :ok <- check(inf in [:self, :target], :silent),
         :ok <- check_dialog(state, inf),
         :ok <- check(act_allowed?(state, inf), :silent),
         :ok <- check(is_nil(Map.get(state, :vending_setup)), busy_notice()),
         :ok <- check(state.game_state.action_state != :sitting, :silent),
         :ok <- not_ok(state, skill_id, now),
         :ok <- check_ready(state, skill_id, now, [@cast_cancel]),
         :ok <- check(not basilica_locked?(state, skill_id), :silent),
         :ok <- check(not menu_open?(state), :silent) do
      target = self_target(state, skill_id, inf, target)
      {:use, use_targeted(state, skill_id, max(requested, 1), target, inf)}
    end
  end

  @doc "Decides a request to use `skill_id` on the cell `{x, y}` at `requested`."
  @spec ground(SessionState.t(), integer(), non_neg_integer(), term(), integer()) :: decision()
  def ground(state, skill_id, requested, cell, now) do
    with :ok <- check(inf(skill_id) == :ground, :silent),
         :ok <- check(not SessionState.work_in_progress?(state), busy_notice()),
         :ok <- not_ok(state, skill_id, now),
         :ok <- check(not seated_input?(state, skill_id), {:fail, :failed}),
         :ok <- check_ready(state, skill_id, now, []),
         :ok <- check(not basilica_locked?(state, skill_id), :silent),
         :ok <- check(not menu_open?(state), :silent) do
      {:use, use_ground(state, skill_id, requested, cell)}
    end
  end

  @doc """
  Whether a request to use `skill_id` of `kind` would end the invincibility
  now. The level and target do not change the answer.
  """
  @spec ends_invincibility?(SessionState.t(), :targeted | :ground, integer()) :: boolean()
  def ends_invincibility?(state, kind, skill_id) do
    now = System.monotonic_time(:millisecond)
    %PlayerState{character_id: id, x: x, y: y} = state.game_state

    decision =
      case kind do
        :targeted -> targeted(state, skill_id, 1, id, now)
        :ground -> ground(state, skill_id, 1, {x, y}, now)
      end

    match?({:use, %{ends_invincibility?: true}}, decision)
  end

  @doc "The map and cooldown restrictions every request kind checks (`UseRestrictions.check/4`)."
  @spec not_ok(SessionState.t(), integer(), integer()) :: :ok | {:refuse, reply()}
  def not_ok(state, skill_id, now),
    do:
      UseRestrictions.check(state.game_state, skill_id, Map.get(state, :pending_item_skill), now)

  # An NPC dialog lets through only a skill aimed at the user, while its script
  # allows item use and no work flag is held.
  defp check_dialog(state, inf) do
    allowed =
      not SessionState.npc_dialog?(state) or
        (inf == :self and SessionState.npc_item_flag?(state) and
           not SessionState.work_in_progress?(state))

    check(allowed, busy_notice())
  end

  defp busy_notice do
    if GameMode.mode() == :renewal, do: {:notice, :SYSTEM_NOTICE_ID_BUSY}, else: :silent
  end

  # A trade, chat room, vending stall, storage window or a body state other than
  # Burning refuses the request, unless a storage window is open and the skill
  # targets the user.
  defp act_allowed?(state, inf) do
    game_state = state.game_state

    busy =
      Map.get(state, :trade) != nil or game_state.waiting_room != nil or
        game_state.action_state == :vending or storage_open?(state) or
        body_state(game_state) not in [0, @burning]

    not busy or (storage_open?(state) and inf == :self)
  end

  defp storage_open?(state),
    do: state.game_state.storage != nil or Map.get(state, :guild_storage_ctx) != nil

  defp body_state(%PlayerState{character_id: id}),
    do: StatusDisplay.spawn_state(:player, id).body_state

  defp seated_input?(state, skill_id),
    do:
      state.game_state.action_state == :sitting and
        SkillTextInputHandler.input_required?(skill_id)

  # A cast in flight lets through only the listed skills, and skips the act
  # delay for them; otherwise an item skill skips the act delay.
  defp check_ready(%{game_state: %PlayerState{casting: casting}}, skill_id, _now, passes)
       when casting != nil,
       do: check(skill_id in passes, :silent)

  defp check_ready(state, skill_id, now, _passes) do
    ready = item_skill(state, skill_id) != nil or PlayerState.act_ready?(state.game_state, now)
    check(ready, delay_reply(state))
  end

  defp delay_reply(state), do: UseRestrictions.delay_reply(state.game_state)

  defp basilica_locked?(state, skill_id) do
    id = state.game_state.character_id

    GameMode.mode() == :pre_renewal and
      (StatusStorage.has_status?(:player, id, :sc_basilica) or
         (skill_id != @basilica and StatusStorage.has_status?(:player, id, :sc_basilica_caster)))
  end

  # The skill's own menus, Arrow Crafting's list and a pending text prompt; the
  # Autospell menu stays open for the next request.
  defp menu_open?(state) do
    case Map.get(state, :pending_skill_menu) do
      %{skill_id: @autospell} ->
        false

      nil ->
        SessionState.system_dialog?(state) or Map.get(state, :pending_skill_text_input) != nil

      _menu ->
        true
    end
  end

  # The combo follow-ups are user-targeted, but their target comes from the
  # combo itself, so the client's choice is kept for the combo to resolve.
  defp self_target(state, skill_id, :self, _target) when skill_id not in @combo_skills,
    do: state.game_state.character_id

  defp self_target(_state, _skill_id, _inf, target), do: target

  defp use_targeted(state, skill_id, level, target, inf) do
    case item_skill(state, skill_id) do
      %{level: item_level} ->
        proceed(:item, item_level, target, inf != :self, false)

      nil ->
        level = Caster.Player.request_level(state.game_state, skill_id, level)
        proceed(:skill, level, target, true, true)
    end
  end

  defp use_ground(state, skill_id, requested, cell) do
    case item_skill(state, skill_id) do
      %{level: item_level} ->
        proceed(:item, item_level, cell, true, false)

      nil ->
        own = Caster.Player.own_level(state.game_state, skill_id)
        level = if own > 0 and requested > 0, do: min(requested, own), else: 0
        proceed(:skill, level, cell, true, true)
    end
  end

  defp proceed(origin, level, target, ends?, clears?) do
    %{
      origin: origin,
      level: level,
      target: target,
      ends_invincibility?: ends?,
      clears_item_skill?: clears?
    }
  end

  defp item_skill(%{pending_item_skill: %{skill_id: skill_id} = item}, skill_id), do: item
  defp item_skill(_state, _skill_id), do: nil

  # The request kind a skill accepts: a ground skill, one aimed at the user,
  # one aimed at a unit, or none for a passive or unknown skill. Vending and
  # the Monk combo follow-ups target the user.
  defp inf(@vending), do: :self
  defp inf(skill_id) when skill_id in @combo_skills, do: :self
  defp inf(skill_id), do: catalog_inf(skill_id)

  defp catalog_inf(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, %{target_type: :ground}} -> :ground
      {:ok, %{target_type: :self}} -> :self
      {:ok, %{target_type: :passive}} -> :none
      {:ok, _definition} -> :target
      :error -> :none
    end
  end

  defp check(true, _reply), do: :ok
  defp check(false, reply), do: {:refuse, reply}
end
