defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autospell do
  @moduledoc """
  SC_AUTOSPELL - the bolt armed by `SA_AUTOSPELL`, procced by the holder's weapon
  hits.

  The instance's `state` carries the whole proc:

    * `:skill` - the catalog name of the armed bolt
    * `:max_level` - the highest level it may proc at (`SaAutospell.max_level/3`);
      renewal Hindsight 1 arms 0, and a proc rolled at level 0 casts nothing
    * `:chance` - the per-hit proc chance (`SaAutospell.proc_chance/1`)

  The values mirror it (`val2` the bolt's skill id, `val3` the max level, `val4`
  the chance), so the status is kept across a logout and a restore rebuilds the
  state from them.

  Recursion is structurally impossible and needs no guard: `on_dealt_damage/4`
  fires only from the weapon-attack path (`Combat.dispatch_dealt_damage/4`) and
  every bolt it casts is magic, which never re-enters that path.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_autospell,
    remove_on_death: false,
    properties: [:buff],
    icon: :autospell,
    no_dispel: true,
    no_clear_buff: false

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition

  @impl true
  def on_apply(_target, instance, %{loaded: true}) do
    {:ok, %{name: skill}} = Catalog.by_id(instance.val2)

    {:ok, %{instance | state: %{skill: skill, max_level: instance.val3, chance: instance.val4}}}
  end

  def on_apply(_target, instance, _context), do: {:ok, instance}

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

      case proc_level(max_level, roll.()) do
        0 -> {:ok, instance}
        level -> {:ok, instance, [{:auto_cast, skill, level, {:unit, victim_id}}]}
      end
    else
      {:ok, instance}
    end
  end

  @doc """
  The level the bolt procs at, given the armed `max_level` and a 0..99 roll.

  A roll of 50+ halves the level, 15+ subtracts one, below that it is untouched;
  a level-1 (or level-0) bolt is never reduced.
  """
  @spec proc_level(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def proc_level(level, _roll) when level <= 1, do: level
  def proc_level(level, roll) when roll >= 50, do: div(level, 2)
  def proc_level(level, roll) when roll >= 15, do: level - 1
  def proc_level(level, _roll), do: level

  # rAthena's `rnd()%100`: a uniform integer in 0..99.
  defp roll, do: :rand.uniform(100) - 1
end
