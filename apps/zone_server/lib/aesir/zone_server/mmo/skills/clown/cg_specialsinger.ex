defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgSpecialsinger do
  @moduledoc """
  Skilled Special Singer clears the ten-second skill lock and movement/ASPD
  penalty after a paired renewal ensemble. It costs one SP and has a one-minute
  cooldown, succeeding harmlessly without fatigue. Absent from the pre-renewal tree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 5068,
    name: :cg_specialsinger,
    display_name: "Skilled Special Singer",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: [1],
    after_cast_delay: [300],
    cooldown: [60_000],
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%PlayerState{character_id: id} = caster, :self, _level, _definition) do
    :ok = StatusInterpreter.remove_status(:player, id, :sc_ensemblefatigue, owner_refresh: :defer)
    {:ok, caster}
  end
end
