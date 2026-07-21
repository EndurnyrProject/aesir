defmodule Aesir.ZoneServer.Mmo.Combat.PendingWeaponHit do
  @moduledoc """
  An unresolved weapon swing paused while a target offers Root establishment.

  The descriptor intentionally retains only the information needed to resume
  scheduling and restart attack selection. It never retains damage or code.
  """

  use TypedStruct

  @type unit_ref :: {:player | :mob, non_neg_integer()}
  @type monk_ref :: %{unit: {:player, non_neg_integer()}, pid: pid()}
  @type phase :: :offered | :claimed | :resumed | :suppressed | :cancelled
  @type resolution :: :resume | {:suppress, reference()} | :cancel

  typedstruct do
    field :id, reference(), enforce: true
    field :attacker, unit_ref(), enforce: true
    field :target, unit_ref(), enforce: true
    field :monk_ref, monk_ref(), enforce: true
    field :link_id, reference() | nil, default: nil
    field :deadline_at, integer(), enforce: true
    field :swing_at, integer(), enforce: true
    field :next_attack_at, integer(), enforce: true
    field :phase, phase(), default: :offered
    field :continuation, :pre_trifecta, default: :pre_trifecta
  end

  @doc "Creates a pending swing that will resume from the pre-Trifecta decision point."
  @spec new(reference(), unit_ref(), unit_ref(), monk_ref(), integer(), integer(), integer()) ::
          t()
  def new(
        id,
        attacker,
        target,
        %{unit: {:player, monk_id}, pid: monk_pid} = monk_ref,
        deadline_at,
        swing_at,
        next_attack_at
      )
      when is_integer(monk_id) and monk_id >= 0 and is_pid(monk_pid) do
    %__MODULE__{
      id: id,
      attacker: attacker,
      target: target,
      monk_ref: monk_ref,
      deadline_at: deadline_at,
      swing_at: swing_at,
      next_attack_at: next_attack_at
    }
  end

  @doc "Attaches the Root-owned link created after the offer is accepted."
  @spec claim(t(), reference()) :: {:ok, t()} | :already_resolved | :invalid_link_id
  def claim(%__MODULE__{}, link_id) when not is_reference(link_id), do: :invalid_link_id

  def claim(%__MODULE__{phase: :offered} = pending, link_id) do
    {:ok, %{pending | phase: :claimed, link_id: link_id}}
  end

  def claim(%__MODULE__{}, _link_id), do: :already_resolved

  @doc "Applies a terminal resolution once."
  @spec resolve(t(), resolution()) :: {:ok, t()} | :already_resolved
  def resolve(%__MODULE__{phase: phase} = pending, :resume) when phase in [:offered, :claimed],
    do: {:ok, %{pending | phase: :resumed}}

  def resolve(%__MODULE__{phase: :claimed, link_id: link_id} = pending, {:suppress, link_id}) do
    {:ok, %{pending | phase: :suppressed}}
  end

  def resolve(%__MODULE__{phase: phase} = pending, :cancel) when phase in [:offered, :claimed],
    do: {:ok, %{pending | phase: :cancelled}}

  def resolve(%__MODULE__{}, _resolution), do: :already_resolved

  @doc "Builds the asynchronous Root offer for an unresolved weapon swing."
  @spec offer_message(t()) ::
          {:pending_weapon_hit_offer, reference(), unit_ref(), unit_ref(), monk_ref(), integer()}
  def offer_message(%__MODULE__{} = pending) do
    {:pending_weapon_hit_offer, pending.id, pending.attacker, pending.target, pending.monk_ref,
     pending.deadline_at}
  end

  @doc "Asynchronously notifies the Root owner that a swing is awaiting a link."
  @spec dispatch_offer(t()) :: :ok
  def dispatch_offer(%__MODULE__{} = pending) do
    send(pending.monk_ref.pid, offer_message(pending))
    :ok
  end

  @doc "Builds the coordinator submission after Root has accepted an offer."
  @spec claim_submission_message(t()) ::
          {:pending_weapon_hit_pair_submission, reference(), t()}
  def claim_submission_message(%__MODULE__{phase: :claimed, link_id: link_id} = pending)
      when is_reference(link_id) do
    {:pending_weapon_hit_pair_submission, link_id, pending}
  end

  @doc "Builds the asynchronous cancellation notice for the Root offer owner."
  @spec cancellation_message(t()) :: {:pending_weapon_hit_cancelled, reference(), tuple()}
  def cancellation_message(%__MODULE__{
        phase: :cancelled,
        link_id: nil,
        attacker: attacker,
        id: id
      }) do
    {:pending_weapon_hit_cancelled, id, {:offer, attacker}}
  end

  def cancellation_message(%__MODULE__{phase: :cancelled, link_id: link_id, id: id}) do
    {:pending_weapon_hit_cancelled, id, {:claim, link_id}}
  end
end
