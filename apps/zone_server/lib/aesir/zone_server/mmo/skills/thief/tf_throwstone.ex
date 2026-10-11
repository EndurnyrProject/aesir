defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfThrowstone do
  @moduledoc """
  Stone Fling (TF_THROWSTONE). Fixed-damage misc attack that can stun or blind.

  Misc damage ignores flee and cannot miss, so the status rolls run on every
  hit that was dealt; a hit the caster's own Gravitation Field suppressed
  (Stapo Card grants the skill to any wearer) rolls nothing.

  Renewal and pre-renewal agree on the hit: 50 fixed neutral damage from a player
  (30 from a monster) at seven cells, consuming one Stone. A player caster rolls a
  3% stun and, only when that fails, a 3% blind; a monster caster rolls a 5% stun
  and never blinds. Stun lasts 4.5 s and blind 20 s in renewal; 5 s and 30 s in
  pre-renewal. Renewal adds a 0.1 s after-cast delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 152,
    name: :tf_throwstone,
    requires: [],
    display_name: "Stone Fling",
    max_level: 1,
    ignore_noncrit_atk_bonus: [renewal: true, pre_renewal: false],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :misc,
    element: :neutral,
    range: 7,
    sp_cost: [2],
    after_cast_delay: [renewal: [100], pre_renewal: [0]],
    item_cost: [%{id: 7049, amount: 1}],
    quest_skill: true,
    quest_owner_job: :thief

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_damage 50
  @mob_damage 30
  @player_stun_chance 3
  @mob_stun_chance 5
  @blind_chance 3

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      base_damage: base_damage(caster),
      element: :neutral,
      report_hit: true
    ]

    case Combat.execute_misc_attack(caster, target, opts) do
      {:ok, %{hit?: true}} ->
        maybe_stun_or_blind(caster, target)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_stun_or_blind(caster, target) do
    {unit_type, unit_id} = target_ref(target)
    {source_type, source_id} = source_ref(caster)

    status_opts = [
      duration: stun_duration_ms(),
      success_rate: stun_chance(caster),
      caster_id: source_id,
      source_type: source_type
    ]

    stunned = StatusInterpreter.apply_status(unit_type, unit_id, :sc_stun, status_opts)

    if stunned != :ok and player?(caster),
      do: blind(unit_type, unit_id, {source_type, source_id})

    :ok
  end

  defp player?(%{character_id: _}), do: true
  defp player?(_caster), do: false

  defp base_damage(%{character_id: _}), do: @player_damage
  defp base_damage(_non_player), do: @mob_damage

  defp blind(unit_type, unit_id, {source_type, source_id}) do
    StatusInterpreter.apply_status(unit_type, unit_id, :sc_blind,
      duration: blind_duration_ms(),
      success_rate: @blind_chance,
      caster_id: source_id,
      source_type: source_type
    )
  end

  defp stun_chance(%{character_id: _}), do: @player_stun_chance
  defp stun_chance(_non_player), do: @mob_stun_chance

  defp stun_duration_ms do
    case GameMode.mode() do
      :renewal -> 4_500
      :pre_renewal -> 5_000
    end
  end

  defp blind_duration_ms do
    case GameMode.mode() do
      :renewal -> 20_000
      :pre_renewal -> 30_000
    end
  end

  defp source_ref(%{character_id: unit_id}), do: {:player, unit_id}
  defp source_ref(%{instance_id: unit_id}), do: {:mob, unit_id}
  defp source_ref(%{world_gid: unit_id}), do: {:homunculus, unit_id}

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
