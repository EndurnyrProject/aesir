defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBodyrelocation do
  @moduledoc """
  Snap (MO_BODYRELOCATION), a prevalidated same-map relocation.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 264,
    name: :mo_bodyrelocation,
    display_name: "Snap",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 18,
    sp_cost: [14],
    sphere_cost: [1]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, {:ground, x, y}, _level, _definition) do
    case ForcedMovement.validate(caster, x, y, Formulas.snap_range()) do
      {:ok, _directive} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(%{character_id: character_id}, _target, _level, _definition) do
    %Cost{
      sp: Formulas.snap_sp_cost(),
      spheres: Formulas.snap_sphere_cost(fury_active?(character_id))
    }
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:ground, x, y}, _level, _definition) do
    with {:ok, directive} <- ForcedMovement.validate(caster, x, y, Formulas.snap_range()) do
      {:ok, PlayerState.put_pending_forced_movement(caster, directive)}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp fury_active?(character_id) do
    case StatusStorage.get_status(:player, character_id, :sc_explosionspirits) do
      %{expires_at: nil} -> true
      %{expires_at: expires_at} when is_integer(expires_at) -> expires_at > monotonic_now()
      _status -> false
    end
  end

  defp monotonic_now, do: System.monotonic_time(:millisecond)
end
