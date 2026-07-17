defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autospell do
  @moduledoc """
  SC_AUTOSPELL - the bolt armed by `SA_AUTOSPELL`, procced by the holder's weapon
  hits (rAthena battle.cpp:7489-7527).

  The instance's `state` carries the whole proc:

    * `:skill` - the catalog name of the armed bolt
    * `:max_level` - the highest level it may proc at (`SA_AUTOSPELL.max_level/2`)
    * `:chance` - the per-hit proc chance, `2 * autospell_level` percent
      (status.cpp:10988, renewal branch)

  Recursion is structurally impossible and needs no guard: `on_dealt_damage/4`
  fires only from the weapon-attack path (`Combat.dispatch_dealt_damage/4`) and
  every bolt it casts is magic, which never re-enters that path.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_autospell,
    properties: [:buff],
    icon: :autospell,
    no_save: true,
    no_dispel: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition

  @impl true
  def on_dealt_damage(target, instance, hit_info, context),
    do: on_dealt_damage(target, instance, hit_info, context, &roll/0)

  @doc false
  @spec on_dealt_damage(
          Definition.target(),
          Aesir.ZoneServer.Mmo.StatusEntry.t(),
          map(),
          Definition.context(),
          (-> non_neg_integer())
        ) :: Definition.hook_result()
  def on_dealt_damage(_target, instance, hit_info, _context, roll) do
    %{skill: skill, max_level: max_level, chance: chance} = instance.state

    if roll.() < chance do
      {_victim_type, victim_id} = hit_info.target
      level = proc_level(max_level, roll.())

      {:ok, instance, [{:auto_cast, skill, level, {:unit, victim_id}}]}
    else
      {:ok, instance}
    end
  end

  @doc """
  The level the bolt procs at, given the armed `max_level` and a 0..99 roll.

  A roll of 50+ halves the level, 15+ subtracts one, below that it is untouched;
  a level-1 bolt is never reduced (battle.cpp:7497-7501).
  """
  @spec proc_level(pos_integer(), non_neg_integer()) :: pos_integer()
  def proc_level(1, _roll), do: 1
  def proc_level(level, roll) when roll >= 50, do: div(level, 2)
  def proc_level(level, roll) when roll >= 15, do: level - 1
  def proc_level(level, _roll), do: level

  # rAthena's `rnd()%100`: a uniform integer in 0..99.
  defp roll, do: :rand.uniform(100) - 1
end
