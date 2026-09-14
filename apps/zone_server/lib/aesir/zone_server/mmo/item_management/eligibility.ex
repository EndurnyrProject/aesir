defmodule Aesir.ZoneServer.Mmo.ItemManagement.Eligibility do
  @moduledoc """
  Pure, shared validation for mode-aware item restrictions.

  Identity is validated before any restriction so malformed runtime state never
  broadens access.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility

  @typedoc "Character identity required to evaluate item restrictions."
  @type context :: %{job_id: integer(), base_level: integer(), sex: String.t()}

  @typedoc "A failed identity or item restriction."
  @type reason ::
          :invalid_identity
          | :job_restricted
          | :class_restricted
          | :gender_restricted
          | :level_restricted

  @doc "Validates that an eligibility context identifies a playable character."
  @spec validate_context(context(), ItemEligibility.mode()) ::
          :ok | {:error, :invalid_identity}
  def validate_context(
        %{job_id: job_id, base_level: base_level, sex: sex},
        mode
      )
      when is_integer(job_id) and is_integer(base_level) and base_level > 0 and
             sex in ["M", "F"] do
    case ItemEligibility.classify(job_id, mode) do
      {:ok, _profile} -> :ok
      {:error, :unknown_job} -> {:error, :invalid_identity}
    end
  end

  def validate_context(_context, _mode), do: {:error, :invalid_identity}

  @doc "Checks an item's restrictions against an explicit game mode."
  @spec check(ItemDefinition.t(), context(), ItemEligibility.mode()) ::
          :ok | {:error, reason()}
  def check(%ItemDefinition{} = item, context, mode) do
    with :ok <- validate_context(context, mode),
         {:ok, profile} <- ItemEligibility.classify(context.job_id, mode),
         :ok <- check_level(item, context.base_level),
         :ok <- check_gender(item, context.sex),
         :ok <- check_family(item, profile.family),
         :ok <- check_class(item, profile.classes) do
      :ok
    else
      {:error, :unknown_job} -> {:error, :invalid_identity}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Checks an item's restrictions against the active game mode."
  @spec check(ItemDefinition.t(), context()) :: :ok | {:error, reason()}
  def check(%ItemDefinition{} = item, context),
    do: check(item, context, ItemEligibility.mode())

  defp check_level(%ItemDefinition{equip_level_min: min, equip_level_max: max}, level) do
    if (min > 0 and level < min) or (max > 0 and level > max),
      do: {:error, :level_restricted},
      else: :ok
  end

  defp check_gender(%ItemDefinition{gender: :both}, _sex), do: :ok
  defp check_gender(%ItemDefinition{gender: :male}, "M"), do: :ok
  defp check_gender(%ItemDefinition{gender: :female}, "F"), do: :ok
  defp check_gender(%ItemDefinition{}, _sex), do: {:error, :gender_restricted}

  defp check_family(%ItemDefinition{jobs: :all}, _family), do: :ok

  defp check_family(%ItemDefinition{jobs: jobs}, family) do
    if family in jobs, do: :ok, else: {:error, :job_restricted}
  end

  defp check_class(%ItemDefinition{classes: classes}, profile_classes) do
    if Enum.any?(profile_classes, &(&1 in classes)),
      do: :ok,
      else: {:error, :class_restricted}
  end
end
