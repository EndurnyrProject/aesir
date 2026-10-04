defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwGanbantein do
  @moduledoc """
  Ganbantein (HW_GANBANTEIN). Targets a cell up to 18 cells away and, with an 80%
  chance, removes every ground skill cell in the 3x3 around it, traps and Land
  Protector included; a song or dance is removed only when its centre lies in
  the area. A failed attempt still costs SP and the after-cast delay but spares
  the Yellow and Blue Gemstone.

  Renewal: 3 s fixed cast. Pre-renewal: 3 s variable cast. Both modes: 40 SP and
  a 5 s after-cast delay.

  Monsters cast it through `cast/4`, which is caster-generic.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 483,
    name: :hw_ganbantein,
    requires: [],
    display_name: "Ganbantein",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 18,
    splash_radius: 1,
    sp_cost: [40],
    cast_time: [renewal: [], pre_renewal: [3_000]],
    fixed_cast_time: [renewal: [3_000], pre_renewal: []],
    after_cast_delay: [5_000],
    item_cost: [%{id: 715, amount: 1}, %{id: 717, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager

  @behaviour Active

  @success_chance 80

  @doc """
  Clears the area on a successful roll. `opts` accepts `:rng`, a
  `(pos_integer() -> pos_integer())` function defaulting to `&:rand.uniform/1`.
  """
  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t(), keyword()) ::
          {:ok, Active.caster()} | {:ok, Active.caster(), :no_consume}
  def cast(caster, {:ground, x, y}, _level, definition, opts \\ []) do
    rng = Keyword.get(opts, :rng, &:rand.uniform/1)

    if rng.(100) <= @success_chance do
      Manager.clear_area(caster.map_name, Layout.square({x, y}, definition.splash_radius))
      {:ok, caster}
    else
      {:ok, caster, :no_consume}
    end
  end
end
