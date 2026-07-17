defmodule Aesir.ZoneServer.Mmo.Skills.SaCastcancel do
  @moduledoc """
  Cast Cancel (SA_CASTCANCEL). Aborts the caster's own in-flight cast.

  The abort and its SP penalty are driven session-side by
  `Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler`, which intercepts this
  skill before its idle gate: the cast descriptor it needs lives on the session,
  and cancelling requires killing the cast timer. This module therefore only
  contributes the definition and the `:not_casting` guard, so the interpreter
  charges nothing when there is nothing to cancel.

  rAthena (`skills/mage/castcancel.cpp`) zaps
  `skill_get_sp(cancelled_skill, cancelled_level) * (90 - 20*(lv-1)) / 100`.
  Because Aesir charges SP at castend (like rAthena), this is a penalty paid
  *instead of* the cancelled skill's full cost, not a refund.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 275,
    name: :sa_castcancel,
    display_name: "Cast Cancel",
    max_level: 5,
    target_type: :self,
    sp_cost: [2, 2, 2, 2, 2]

  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @impl Active
  def validate(%{casting: nil}, _target, _level, _definition), do: {:error, :not_casting}
  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  def cast(caster, :self, _level, _definition), do: {:ok, caster}
end
