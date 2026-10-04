defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfMemorize do
  @moduledoc """
  Foresight (PF_MEMORIZE). Grants `:sc_memorize`: the next five casts of learned
  skills take 50% less variable cast time.

  Renewal: 2.5 s fixed cast. Pre-renewal: 5 s variable cast. Both modes: 1 SP.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 403,
    name: :pf_memorize,
    status: :sc_memorize,
    display_name: "Foresight",
    max_level: 1,
    ignore_dex: true,
    ignore_status_cast: true,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    sp_cost: [1],
    cast_time: [renewal: [], pre_renewal: [5_000]],
    fixed_cast_time: [renewal: [2_500], pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, _definition) do
    with :ok <-
           StatusInterpreter.apply_status(:player, id, :sc_memorize, val1: level, caster_id: id) do
      {:ok, caster}
    end
  end
end
