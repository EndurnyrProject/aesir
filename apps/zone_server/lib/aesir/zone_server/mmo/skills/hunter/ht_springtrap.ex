defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSpringtrap do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 131,
    name: :ht_springtrap,
    display_name: "Spring Trap",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: [4, 5, 6, 7, 8],
    sp_cost: [10, 10, 10, 10, 10]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, {:ground, _x, _y}, _level, _definition) do
    if FalconHandler.falcon?(caster), do: :ok, else: {:error, :falcon_required}
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:ground, x, y}, _level, _definition) do
    with {:ok, _transition} <- Manager.spring_trap(caster.map_name, x, y) do
      {:ok, caster}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}
end
