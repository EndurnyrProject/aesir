defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoCombofinish do
  @moduledoc """
  Raging Thrust (MO_COMBOFINISH).

  Landing a Thrust closes the ordinary combo chain, but when the caster can
  immediately follow it with Asura Strike - knowing that skill, holding Fury,
  and carrying at least four spirit spheres - it instead opens an `:extremity`
  combo window so Asura can be cast as the chain's finisher.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 273,
    name: :mo_combofinish,
    display_name: "Raging Thrust",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -2,
    sp_cost: [3, 4, 5, 6, 7],
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active

  @asura_skill_id 271
  @asura_sphere_threshold 4
  @fury :sc_explosionspirits

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_combo}
  def validate(caster, {:unit, target_id}, _level, _definition) do
    case Combo.validate(caster.combo, :thrust, target_id, now()) do
      {:ok, _target} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    now = now()

    with {:ok, target} <- Combo.validate(caster.combo, :thrust, target_id, now),
         {:ok, target_type, _position} <- Combat.resolve_target_position(target_id),
         {:ok, ^target} <- Combo.validate(caster.combo, :thrust, {target_type, target_id}, now),
         :ok <-
           Combat.execute_skill_attack(
             caster,
             target_id,
             skill_options(caster, level, definition)
           ),
         duration <- Enum.at(definition.after_cast_delay, level - 1, 0),
         {:ok, combo} <- maybe_open_extremity(caster, target, now, duration) do
      if combo.stage == :extremity,
        do: Process.send_after(self(), {:combo_timeout, combo.generation}, duration)

      {:ok, %{caster | combo: combo}}
    else
      {:error, _reason} = error -> error
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_combo}

  # Opens the Asura follow-up window when the caster can immediately use it;
  # otherwise the chain closes exactly as before.
  defp maybe_open_extremity(caster, target, now, duration) do
    if asura_follow_up_ready?(caster) do
      Combo.advance(caster.combo, :thrust, :extremity, target, now + duration, now)
    else
      {:ok, Combo.cancel(caster.combo)}
    end
  end

  defp asura_follow_up_ready?(caster) do
    Map.get(caster.stats.progression.learned_skills, @asura_skill_id, 0) > 0 and
      SpiritSpheres.count(caster.spirit_spheres) >= @asura_sphere_threshold and
      fury_active?(caster.character_id)
  end

  defp fury_active?(character_id) do
    case StatusStorage.get_status(:player, character_id, @fury) do
      %{expires_at: nil} -> true
      %{expires_at: expires_at} when is_integer(expires_at) -> expires_at > now()
      _status -> false
    end
  end

  defp skill_options(caster, level, definition) do
    [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: Formulas.thrust_ratio(level, caster.stats.base_stats.str),
      hit_count: Formulas.thrust_hit_count(),
      skip_crit: true
    ]
  end

  defp now, do: System.monotonic_time(:millisecond)
end
