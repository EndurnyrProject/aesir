defmodule Mix.Tasks.Aesir.Gen.Constants do
  @shortdoc "Generates rAthena display-constant resolver modules from the C++ headers"
  @moduledoc """
  Parses the rAthena enum blocks and emits compiled atom -> integer resolver
  modules under `mmo/constants/`, so status `Definition`s can reference readable
  atoms and `StatusDisplay` can resolve them to the numeric ids the client
  expects on the wire.

      mix aesir.gen.constants [<rathena_root>]

  `<rathena_root>` defaults to the `:rathena_root` application env of
  `:zone_server`, falling back to `../rathena`. The task reads the enum bodies
  out of `src/map/status.hpp` and `src/map/script.hpp`, transcribing them in
  full (like `status_types.ex` mirrors every `SC_*`) so a referenced atom can
  never be missing.

  The emitted modules are deterministic (members ordered by integer value) and
  the task is idempotent: re-running produces no git diff. Run only when syncing
  rAthena.

  ## Parsing rules

  For each enum block the parser:

    * drops `//` line comments and `/* */` block comments,
    * honors an explicit `NAME = value` (hex `0x..`, decimal or negative),
    * auto-increments a bare `NAME` from the previous value + 1,
    * resets the running counter at the start of each enum,
    * keys each entry by its name with the per-enum prefix stripped and
      downcased into an atom.
  """
  use Mix.Task

  @specs [
    {"Aesir.ZoneServer.Mmo.Efst", "efst.ex", "src/map/status.hpp", "efst_type", "EFST_",
     "efst_type (EFST_*) display icon ids (the EFST buff/debuff icon bar)."},
    {"Aesir.ZoneServer.Mmo.Opt1", "opt1.ex", "src/map/status.hpp", "e_sc_opt1", "OPT1_",
     "e_sc_opt1 (OPT1_*) single-valued sprite body-state ids."},
    {"Aesir.ZoneServer.Mmo.Opt2", "opt2.ex", "src/map/status.hpp", "e_sc_opt2", "OPT2_",
     "e_sc_opt2 (OPT2_*) sprite health-state bitmask ids."},
    {"Aesir.ZoneServer.Mmo.Opt3", "opt3.ex", "src/map/status.hpp", "e_sc_opt3", "OPT3_",
     "e_sc_opt3 (OPT3_*) sprite virtue bitmask ids."},
    {"Aesir.ZoneServer.Mmo.Option", "option.ex", "src/map/status.hpp", "e_option", "OPTION_",
     "e_option (OPTION_*) sprite effect-state bitmask ids."},
    {"Aesir.ZoneServer.Mmo.EffectId", "effect_id.ex", "src/map/script.hpp", "e_special_effects",
     "EF_", "e_special_effects (EF_*) one-shot special-effect ids."}
  ]

  @out_dir Path.join(~w(apps zone_server lib aesir zone_server mmo constants))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || rathena_root()
    File.mkdir_p!(@out_dir)

    Enum.each(@specs, fn {module, file, header, enum, prefix, doc} ->
      source = File.read!(Path.join(rathena, header))

      case parse_enum(source, enum, prefix) do
        {:ok, members} ->
          out = Path.join(@out_dir, file)
          File.write!(out, render_module(module, doc, members))
          Mix.shell().info("  wrote #{map_size(members)} entries -> #{out}")

        {:error, reason} ->
          Mix.raise("could not parse enum #{enum} from #{header}: #{inspect(reason)}")
      end
    end)
  end

  @doc """
  Extracts the named enum body from `source` and parses its members into an
  atom -> integer map, with `prefix` stripped from each member name.

  Returns `{:error, :enum_not_found}` when the enum block is absent.
  """
  @spec parse_enum(String.t(), String.t(), String.t()) ::
          {:ok, %{atom() => integer()}} | {:error, :enum_not_found}
  def parse_enum(source, enum, prefix) do
    with {:ok, body} <- extract_body(source, enum) do
      members =
        body
        |> strip_comments()
        |> String.split(",")
        |> Enum.reduce({%{}, -1}, fn entry, {acc, prev} ->
          reduce_member(entry, prefix, acc, prev)
        end)
        |> elem(0)

      {:ok, members}
    end
  end

  @spec rathena_root() :: String.t()
  defp rathena_root do
    Application.get_env(:zone_server, :rathena_root, "../rathena")
  end

  @spec extract_body(String.t(), String.t()) :: {:ok, String.t()} | {:error, :enum_not_found}
  defp extract_body(source, enum) do
    regex = ~r/enum\s+#{Regex.escape(enum)}\b[^{]*\{(.*?)\}\s*;/s

    case Regex.run(regex, source, capture: :all_but_first) do
      [body] -> {:ok, body}
      nil -> {:error, :enum_not_found}
    end
  end

  @spec strip_comments(String.t()) :: String.t()
  defp strip_comments(body) do
    body
    |> String.replace(~r{/\*.*?\*/}s, "")
    |> String.replace(~r{//[^\n]*}, "")
  end

  @spec reduce_member(String.t(), String.t(), %{atom() => integer()}, integer()) ::
          {%{atom() => integer()}, integer()}
  defp reduce_member(entry, prefix, acc, prev) do
    case parse_member(String.trim(entry), prefix) do
      {:ok, key, :auto} -> {Map.put(acc, key, prev + 1), prev + 1}
      {:ok, key, value} -> {Map.put(acc, key, value), value}
      :skip -> {acc, prev}
    end
  end

  @spec parse_member(String.t(), String.t()) ::
          {:ok, atom(), integer() | :auto} | :skip
  defp parse_member("", _prefix), do: :skip

  defp parse_member(entry, prefix) do
    case String.split(entry, "=", parts: 2) do
      [name] -> with_name(name, prefix, :auto)
      [name, value] -> with_value(name, prefix, value)
    end
  end

  @spec with_value(String.t(), String.t(), String.t()) :: {:ok, atom(), integer()} | :skip
  defp with_value(name, prefix, value) do
    with {:ok, parsed} <- parse_value(String.trim(value)) do
      with_name(name, prefix, parsed)
    end
  end

  @spec with_name(String.t(), String.t(), integer() | :auto) ::
          {:ok, atom(), integer() | :auto} | :skip
  defp with_name(name, prefix, value) do
    name = String.trim(name)

    if String.starts_with?(name, prefix) and Regex.match?(~r/^[A-Z0-9_]+$/, name) do
      key = name |> String.replace_prefix(prefix, "") |> String.downcase() |> String.to_atom()
      {:ok, key, value}
    else
      :skip
    end
  end

  @spec parse_value(String.t()) :: {:ok, integer()} | :skip
  defp parse_value("0x" <> hex), do: {:ok, String.to_integer(hex, 16)}

  defp parse_value(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> :skip
    end
  end

  @spec render_module(String.t(), String.t(), %{atom() => integer()}) :: String.t()
  defp render_module(module, doc, members) do
    entries =
      members
      |> Enum.sort_by(fn {_key, value} -> value end)
      |> Enum.map_join(",\n", fn {key, value} -> "#{inspect(key)} => #{underscore_int(value)}" end)

    """
    defmodule #{module} do
      @moduledoc \"\"\"
      #{doc}

      Generated by `mix aesir.gen.constants` from the rAthena headers. Do not
      edit by hand; re-run the task to regenerate.
      \"\"\"

      @ids %{#{entries}}

      @doc \"\"\"
      Resolves a constant atom to its rAthena numeric id, or `nil` when unknown.
      \"\"\"
      @spec id(atom()) :: integer() | nil
      def id(atom) when is_atom(atom), do: Map.get(@ids, atom)
    end
    """
    |> Code.format_string!()
    |> then(&[&1, ?\n])
    |> IO.iodata_to_binary()
  end

  @spec underscore_int(integer()) :: String.t()
  defp underscore_int(value) when value > -10_000 and value < 10_000, do: Integer.to_string(value)
  defp underscore_int(value) when value < 0, do: "-" <> underscore_int(-value)

  defp underscore_int(value) do
    value
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join("_", &Enum.join/1)
    |> String.reverse()
  end
end
