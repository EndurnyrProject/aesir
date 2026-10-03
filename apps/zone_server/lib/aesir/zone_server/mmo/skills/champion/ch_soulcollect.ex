defmodule Aesir.ZoneServer.Mmo.Skills.Champion.ChSoulcollect do
  @moduledoc """
  Zen (CH_SOULCOLLECT).

  Summons spirit spheres until the caster holds exactly five, every one fresh
  for 10 minutes; spheres already held are replaced, oldest first. The limit is
  five regardless of Summon Spirit Sphere's level. The player session commits
  the returned sphere collection and owns its timer and broadcasts.

  Renewal: 20 SP and a 1 s fixed cast. Pre-renewal: 20 SP and a 2 s cast.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 401,
    name: :ch_soulcollect,
    display_name: "Zen",
    max_level: 1,
    target_type: :self,
    sp_cost: [20],
    cast_time: [renewal: [0], pre_renewal: [2_000]],
    fixed_cast_time: [renewal: [1_000], pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @behaviour Active

  @limit 5

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(caster, :self, _level, _definition) do
    expires_at = System.monotonic_time(:millisecond) + Formulas.spirit_sphere_duration()

    spheres =
      Enum.reduce(1..@limit, caster.spirit_spheres, fn _, acc ->
        acc |> SpiritSpheres.summon(expires_at, @limit) |> elem(0)
      end)

    {:ok, %{caster | spirit_spheres: spheres}}
  end
end
