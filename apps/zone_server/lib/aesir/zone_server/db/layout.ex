defmodule Aesir.ZoneServer.Db.Layout do
  @moduledoc """
  Describes the database directory layout.
  """

  @typedoc "A database mode."
  @type mode :: :renewal | :pre_renewal

  @typedoc "A database domain relative to `priv/db`."
  @type domain :: String.t()

  @typedoc "Whether a domain resolves by wildcard or fixed filename."
  @type kind :: :glob | :file

  @typedoc "The Mix task that imports a domain, when available."
  @type import_task :: String.t() | nil

  @typep domain_info :: {kind(), boolean(), import_task()}

  @domains %{
    "items" => {:glob, false, "aesir.import.items"},
    "mobs" => {:glob, false, "aesir.import.mobs"},
    "spawns" => {:glob, false, "aesir.import.spawns"},
    "jobs" => {:glob, false, "aesir.import.jobs"},
    "quests" => {:glob, false, "aesir.import.quests"},
    "warps" => {:glob, false, "aesir.import.warps"},
    "shops" => {:glob, false, "aesir.import.shops"},
    "statpoint" => {:glob, false, "aesir.import.statpoint"},
    "item_groups" => {:glob, false, "aesir.import.item_groups"},
    "skill_tree" => {:glob, false, nil},
    "castles" => {:glob, false, "aesir.import.castles"},
    "homunculus/species.yml" => {:file, false, "aesir.import.homunculi"},
    "homunculus/exp.yml" => {:file, false, "aesir.import.homunculi"},
    "homunculus/skill_trees.yml" => {:file, false, "aesir.import.homunculi"},
    "produce/recipes.yml" => {:file, false, "aesir.import.produce"},
    "produce/ore_discovery.yml" => {:file, false, "aesir.import.produce"},
    "guild/exp.yml" => {:file, false, "aesir.import.guild"},
    "guild/skill_tree.yml" => {:file, false, "aesir.import.guild"},
    "refine/refine.yml" => {:file, false, "aesir.import.refine"},
    "mob_skills/mob_skills.yml" => {:file, false, "aesir.import.mob_skills"},
    "arrows.yml" => {:file, true, "aesir.import.arrows"},
    "map_flags.yml" => {:file, true, nil},
    "navigation.yml" => {:file, true, nil},
    "level_penalty.yml" => {:file, false, "aesir.import.level_penalty"},
    "level_penalty_exp.yml" => {:file, false, "aesir.import.level_penalty"},
    "level_penalty_mvp_drop.yml" => {:file, false, "aesir.import.level_penalty"},
    "level_penalty_mvp_exp.yml" => {:file, false, "aesir.import.level_penalty"}
  }

  @doc "Returns the directory for a database mode."
  @spec mode_dir(mode()) :: String.t()
  def mode_dir(:renewal), do: "re"
  def mode_dir(:pre_renewal), do: "pre-re"

  @doc "Returns whether a domain resolves to YAML files or a fixed YAML file."
  @spec kind(domain()) :: kind()
  def kind(domain), do: domain |> domain!() |> elem(0)

  @doc "Returns whether a domain is shared across database modes."
  @spec shared?(domain()) :: boolean()
  def shared?(domain), do: domain |> domain!() |> elem(1)

  @doc "Returns the database path relative to `priv/db` for a domain and mode."
  @spec rel_path(domain(), mode()) :: Path.t()
  def rel_path(domain, mode) do
    if shared?(domain), do: domain, else: Path.join(mode_dir(mode), domain)
  end

  @doc "Returns the import-overlay path relative to `priv/db` for a domain."
  @spec import_rel_path(domain()) :: Path.t()
  def import_rel_path(domain) do
    _ = domain!(domain)
    Path.join("import", domain)
  end

  @doc "Returns the importer task for a domain, if one exists."
  @spec import_task(domain()) :: import_task()
  def import_task(domain), do: domain |> domain!() |> elem(2)

  @spec domain!(domain()) :: domain_info()
  defp domain!(domain) do
    case Map.fetch(@domains, domain) do
      {:ok, info} -> info
      :error -> raise ArgumentError, "unknown database domain: #{inspect(domain)}"
    end
  end
end
