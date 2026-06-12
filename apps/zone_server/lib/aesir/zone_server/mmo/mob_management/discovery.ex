defmodule Aesir.ZoneServer.Mmo.MobManagement.Discovery do
  @moduledoc """
  Auto-discovery of definition modules implementing a given behaviour.

  An application's own module list is not reliably available at compile time, so
  discovery happens at runtime by enumerating the modules declared in the app's
  `.app` spec and keeping those that adopt `behaviour`. The result is meant to be
  built once and cached by the caller (see `Mobs`/`Spawns`), so there is no file
  IO or parsing on the hot path.
  """

  @doc """
  Returns every module in `app` that adopts `behaviour`.
  """
  @spec modules_for(atom(), module()) :: [module()]
  def modules_for(app, behaviour) do
    {:ok, modules} = :application.get_key(app, :modules)
    Enum.filter(modules, &adopts?(&1, behaviour))
  end

  @doc """
  Returns true when `module` is loaded and adopts `behaviour`.
  """
  @spec adopts?(module(), module()) :: boolean()
  def adopts?(module, behaviour) do
    Code.ensure_loaded?(module) and
      behaviour in List.flatten(Keyword.get_values(module.module_info(:attributes), :behaviour))
  end
end
