defmodule Aesir.ZoneServer.Mmo.Skill.UseRestrictions do
  @moduledoc """
  The map and cooldown restrictions a player's skill use passes wherever it
  starts: the client request, a cast started again after the player walked into
  range, and an equipment autocast.

  In order: an item skill for Teleport above level 2 passes them all; the
  `noskill` map flag refuses silently unless an item skill is pending; a running
  cooldown refuses with the delay reply; an item skill that keeps no
  requirement passes the rest; the skill's map restriction mask shows the area
  notice; then Teleport, Warp Portal, Vending, Ice Wall and Urgent Call check
  their own map rules.

  An act delay or cooldown refusal is reported only to a player who turned
  delay notices on (`@showdelay`).
  """

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.NoCast
  alias Aesir.ZoneServer.Npc.Proximity
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @teleport 26
  @warp 27
  @identify 40
  @vending 41
  @ice_wall 87
  @emergency_calls [10_013, 10_015]

  @typedoc """
  The reply a refusal sends: nothing, a skill failure with its reason, or a
  client notice.
  """
  @type reply :: :silent | {:fail, atom()} | {:notice, atom()}

  @typedoc "A pending item skill: the skill, its level and whether it keeps its requirement."
  @type item_skill :: %{
          required(:skill_id) => integer(),
          required(:level) => pos_integer(),
          optional(:keep_requirement?) => boolean(),
          optional(atom()) => term()
        }

  @doc """
  Checks `skill_id` for `game_state` at `now`, given the player's pending item
  skill (`nil` when none).
  """
  @spec check(PlayerState.t(), integer(), item_skill() | nil, integer()) ::
          :ok | {:refuse, reply()}
  def check(%PlayerState{} = game_state, skill_id, pending_item, now) do
    %PlayerState{map_name: map_name, skill_cooldowns: cooldowns} = game_state
    item = matching_item(pending_item, skill_id)

    cond do
      teleport_item?(skill_id, item) ->
        :ok

      MapFlags.get(map_name, :noskill) and pending_item == nil ->
        {:refuse, :silent}

      not Cooldown.ready?(cooldowns, skill_id, now) ->
        {:refuse, delay_reply(game_state)}

      requirement_free_item?(item) ->
        :ok

      NoCast.refused?(skill_id, map_name) ->
        {:refuse, {:notice, :SYSTEM_NOTICE_ID_IMPOSSIBLE_SKILL_AREA}}

      true ->
        skill_rule(game_state, skill_id)
    end
  end

  @doc "The reply to an act delay or cooldown refusal: a failure only with `@showdelay` on."
  @spec delay_reply(PlayerState.t()) :: reply()
  def delay_reply(%PlayerState{show_delay: true}), do: {:fail, :skill_interval}
  def delay_reply(_game_state), do: :silent

  defp matching_item(%{skill_id: skill_id} = item, skill_id), do: item
  defp matching_item(_pending_item, _skill_id), do: nil

  defp teleport_item?(@teleport, %{level: level}), do: level > 2
  defp teleport_item?(_skill_id, _item), do: false

  defp requirement_free_item?(nil), do: false
  defp requirement_free_item?(item), do: not Map.get(item, :keep_requirement?, false)

  defp skill_rule(%PlayerState{map_name: map_name}, @warp),
    do: check(not MapFlags.get(map_name, :nowarp), {:notice, :SYSTEM_NOTICE_ID_MAP_CANT_TELEPORT})

  defp skill_rule(%PlayerState{map_name: map_name}, @teleport),
    do:
      check(
        not MapFlags.get(map_name, :noteleport),
        {:notice, :SYSTEM_NOTICE_ID_MAP_CANT_TELEPORT}
      )

  defp skill_rule(%PlayerState{map_name: map_name, x: x, y: y}, @vending),
    do: check(not Proximity.npc_near?(map_name, x, y), {:fail, :npc_nearby})

  defp skill_rule(_game_state, @identify), do: :ok

  defp skill_rule(%PlayerState{map_name: map_name}, @ice_wall),
    do: check(not MapFlags.get(map_name, :noicewall), {:fail, :failed})

  defp skill_rule(%PlayerState{map_name: map_name}, skill_id)
       when skill_id in @emergency_calls,
       do: check(MapFlags.gvg2?(map_name), {:fail, :failed})

  defp skill_rule(_game_state, _skill_id), do: :ok

  defp check(true, _reply), do: :ok
  defp check(false, reply), do: {:refuse, reply}
end
