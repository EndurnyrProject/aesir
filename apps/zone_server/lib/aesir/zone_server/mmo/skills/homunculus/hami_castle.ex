defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HamiCastle do
  @moduledoc "Castling (HAMI_CASTLE)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8005,
    name: :hami_castle,
    display_name: "Castling",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(10, 5),
    cooldown: List.duplicate(1_000, 5)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  def validate(%HomunculusState{} = caster, :self, _level, _definition) do
    with true <- HomunculusState.living?(caster),
         {:ok, {PlayerState, owner, owner_pid}} <-
           Movement.swap_ready(:player, caster.owner_character_id),
         true <- owner_pid == caster.owner_session_pid,
         true <- Unit.living?(owner),
         true <- owner.map_name == caster.map_name,
         {:ok, {HomunculusState, ^caster, ^owner_pid}} <-
           Movement.swap_ready(:homunculus, caster.world_gid) do
      :ok
    else
      _invalid -> {:error, :invalid_castling_endpoint}
    end
  end

  @impl Active
  @spec cast(HomunculusState.t(), :self, 1..5, map()) ::
          {:ok, HomunculusState.t()} | {:local_effects, HomunculusState.t(), [tuple()]}
  def cast(%HomunculusState{} = caster, :self, level, _definition) do
    if chance_success?(level, :rand.uniform(100)) do
      {:local_effects, caster, [{:homunculus, {:castling_swap, caster.world_gid}}]}
    else
      {:ok, caster}
    end
  end

  @doc "Returns whether an inclusive 1..100 roll succeeds at the requested rank."
  @spec chance_success?(1..5, 1..100) :: boolean()
  def chance_success?(level, roll) when level in 1..5 and roll in 1..100,
    do: roll <= 20 * level
end
