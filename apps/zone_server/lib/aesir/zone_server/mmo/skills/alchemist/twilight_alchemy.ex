defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.TwilightAlchemy do
  @moduledoc """
  Shared batch and party rules of the three Twilight Alchemy skills.

  A batch is a Pharmacy production of many copies at once: the recipe must be
  producible for the whole quantity on the current inventory (outside another
  skill's open menu), every material is spent up front, and each copy rolls the
  Pharmacy chance with the caster's living Vanilmirth's Instruction Change. The
  party rules read the caster's party as it stands: a member of the wanted jobs
  must be online, on any map.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Produce
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc "Brews a batch of `qty` copies of `product_id`, or `:error` when it cannot be made now."
  @spec brew(PlayerState.t(), pos_integer(), pos_integer()) :: {:ok, PlayerState.t()} | :error
  def brew(%PlayerState{} = caster, product_id, qty) do
    with {:ok, recipe} <-
           Produce.producible(caster, product_id, -1, caster.open_menu_skill_id, qty),
         {:ok, made} <- Forge.run_batch(caster, recipe, qty, instruction_change_rank(caster)) do
      {:ok, made}
    else
      _not_made -> :error
    end
  end

  @doc """
  The cast result of a skill that shows itself, then brews one batch: success
  when copies were made, otherwise the shown failure (the batch's materials,
  when it could start, stay spent).
  """
  @spec cast_batch(PlayerState.t(), pos_integer(), pos_integer()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :skill_failed, :after_effect}
  def cast_batch(caster, product_id, qty) do
    case brew(caster, product_id, qty) do
      {:ok, %{pending_production_result: %{success: true}} = made} -> {:ok, made}
      {:ok, made} -> {:failed, made, :skill_failed, :after_effect}
      :error -> {:failed, caster, :skill_failed, :after_effect}
    end
  end

  @doc "The cast-begin party rule: `{:ok, caster}` when an online member has one of `jobs`."
  @spec require_party_member(PlayerState.t(), [atom()]) ::
          {:ok, PlayerState.t()} | {:error, :skill_failed}
  def require_party_member(%PlayerState{party_id: party_id} = caster, jobs) when party_id > 0 do
    job_ids = for job <- jobs, {:ok, job_id} <- [AvailableJobs.job_name_to_id(job)], do: job_id

    with {:ok, party} <- PartyManager.get(party_id),
         true <- Enum.any?(PartyState.online_members(party), &(&1.job_id in job_ids)) do
      {:ok, caster}
    else
      _no_member -> {:error, :skill_failed}
    end
  end

  def require_party_member(_caster, _jobs), do: {:error, :skill_failed}

  defp instruction_change_rank(%PlayerState{
         homunculus_summary: %{instruction_change_rank: rank}
       }),
       do: rank

  defp instruction_change_rank(%PlayerState{homunculus_summary: nil}), do: 0
end
