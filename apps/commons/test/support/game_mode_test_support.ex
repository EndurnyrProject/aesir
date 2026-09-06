defmodule Aesir.GameModeTestSupport do
  @moduledoc """
  Configures native ExUnit selection for the booted game mode across umbrella apps.
  """

  alias Aesir.Commons.GameMode

  @doc "Starts ExUnit without discarding exclusions configured by another app or the caller."
  @spec start(keyword()) :: :ok
  def start(opts \\ []) do
    opposite_mode =
      case GameMode.mode() do
        :renewal -> :pre_renewal
        :pre_renewal -> :renewal
      end

    exclusions =
      Enum.uniq(
        Keyword.get(ExUnit.configuration(), :exclude, []) ++
          Keyword.get(opts, :exclude, []) ++
          [game_mode: opposite_mode, integration_re: true, integration_pre_re: true]
      )

    ExUnit.start(Keyword.put(opts, :exclude, exclusions))
  end
end
