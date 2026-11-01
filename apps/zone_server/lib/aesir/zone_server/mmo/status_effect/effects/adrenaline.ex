defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline do
  @moduledoc """
  Adrenaline Rush (SC_ADRENALINE).

  Renewal: a flat +7 attack speed at every level plus 5 plus 3 per level HIT.
  Pre-renewal: a 30 percent attack speed rate for the Blacksmith's own cast (`val2`)
  and 20 percent otherwise, with no HIT. Ends the moment its holder wields
  anything other than a one- or two-handed axe or a mace. Direct script starts
  retain recipient strength (`val2 = 0`), even when the source is the holder.
  Hilt Binding on the player who applies it extends the duration by 10%.
  Quagmire and Decrease AGI prevent new applications.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adrenaline,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate, :hit],
    prevented_by: [:sc_quagmire, :sc_decreaseagi],
    require_weapon: [:one_handed_axe, :two_handed_axe, :mace],
    icon: :adrenaline

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{aspd: 7, hit: 5 + 3 * instance.val1}
      :pre_renewal -> %{aspd_rate: classic_rate(instance)}
    end
  end

  @impl true
  @spec resolve_duration(Definition.target(), StatusEntry.t(), pos_integer()) ::
          {pos_integer(), StatusEntry.t()}
  def resolve_duration(_target, instance, duration) do
    duration =
      with :player <- instance.source_type,
           source_id when is_integer(source_id) <- instance.source_id,
           {:ok, {_, %PlayerState{stats: stats} = caster, _}} when is_map(stats) <-
             UnitRegistry.get_unit(:player, source_id) do
        PartyBuff.duration_for_caster(caster, duration)
      else
        _ -> duration
      end

    {duration, instance}
  end

  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), map()) ::
          {:ok, StatusEntry.t()} | {:error, :wrong_weapon}
  def on_apply(target, instance, context) do
    cond do
      not eligible_weapon?(target) -> {:error, :wrong_weapon}
      context[:loaded] -> {:ok, instance}
      true -> {:ok, %{instance | val3: if(instance.val2 != 0, do: 300, else: 200)}}
    end
  end

  defp eligible_weapon?({:player, id}) do
    case UnitRegistry.get_unit(:player, id) do
      {:ok, {_, %PlayerState{stats: %{equipment: equipment}}, _}} ->
        PlayerStats.weapon_type(equipment) in metadata().require_weapon

      _ ->
        false
    end
  end

  defp eligible_weapon?(_target), do: true

  # `val2` is set when the Blacksmith cast it on themselves.
  defp classic_rate(%{val2: own}) when own != 0, do: 30
  defp classic_rate(_instance), do: 20

  @impl true
  def overlap(target, held, incoming),
    do: Definition.self_cast_overlap(target, held, incoming)
end
