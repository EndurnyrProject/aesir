defmodule Mix.Tasks.Aesir.Import do
  @moduledoc false

  alias Aesir.ZoneServer.Db.Layout

  @db_root Path.join(~w(apps zone_server priv db))

  @spec parse!([String.t()]) :: {Path.t(), Layout.mode()}
  def parse!(args) do
    {options, paths, invalid} = OptionParser.parse(args, strict: [mode: :string])

    unless invalid == [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    mode =
      case Keyword.get(options, :mode, "re") do
        "re" -> :renewal
        "pre-re" -> :pre_renewal
        value -> Mix.raise("invalid --mode #{inspect(value)}; expected re or pre-re")
      end

    {List.first(paths) || "../rathena", mode}
  end

  @spec path(Layout.domain(), Layout.mode()) :: Path.t()
  def path(domain, mode), do: Path.join(@db_root, Layout.rel_path(domain, mode))
end
