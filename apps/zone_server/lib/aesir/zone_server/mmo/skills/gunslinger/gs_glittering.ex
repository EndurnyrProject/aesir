defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGlittering do
  @moduledoc """
  Flip the Coin (GS_GLITTERING).

  A player flips a coin: with a 20 plus 10 per level percent chance it gains a
  coin lasting 10 minutes (at most 10 held), otherwise it loses its oldest coin,
  unless it knows Rich's Coin. The skill's effect shows before the roll either
  way. A cast refuses to begin while the player holds 10 coins. Any other caster
  does nothing.

  Renewal and pre-renewal agree: 2 SP and 1 zeny, no cast time.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 500,
    name: :gs_glittering,
    requires: [],
    display_name: "Flip the Coin",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    ignore_flee: true,
    damage_kind: :misc,
    sp_cost: List.duplicate(2, 5),
    zeny_cost: List.duplicate(1, 5)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active

  @coin_cap 10
  @coin_lifetime_ms 600_000
  @rich_coin 2552

  @impl Active
  def begin_attempt(%PlayerState{} = caster, :self, _level, _definition) do
    if SpiritSpheres.count(caster.spirit_spheres) >= @coin_cap,
      do: {:error, :skill_failed},
      else: {:ok, caster}
  end

  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
  def cast(%PlayerState{} = caster, :self, level, _definition) do
    {:ok, flip(caster, coin_lands?(level, :rand.uniform(100)))}
  end

  def cast(caster, _target, _level, _definition), do: {:ok, caster}

  @doc "Returns whether a 1..100 roll lands the coin at `level`."
  @spec coin_lands?(pos_integer(), 1..100) :: boolean()
  def coin_lands?(level, roll), do: roll <= 20 + 10 * level

  defp flip(caster, true) do
    expires_at = System.monotonic_time(:millisecond) + @coin_lifetime_ms

    {spheres, %SpiritSpheres.Entry{}} =
      SpiritSpheres.summon(caster.spirit_spheres, expires_at, @coin_cap)

    %{caster | spirit_spheres: spheres}
  end

  defp flip(caster, false) do
    with false <- knows_rich_coin?(caster),
         {:ok, spheres, _consumed} <- SpiritSpheres.consume(caster.spirit_spheres, 1) do
      %{caster | spirit_spheres: spheres}
    else
      _kept -> caster
    end
  end

  defp knows_rich_coin?(caster),
    do: Map.get(caster.stats.progression.learned_skills, @rich_coin, 0) > 0
end
