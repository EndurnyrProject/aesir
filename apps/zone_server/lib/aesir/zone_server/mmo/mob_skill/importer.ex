defmodule Aesir.ZoneServer.Mmo.MobSkill.Importer do
  @moduledoc """
  Parses rAthena's `db/re/mob_skill_db.txt` (CSV, `//` comments) into grouped row
  maps for the `mix aesir.import.mob_skills` task; not on any runtime path.

  Each non-comment, non-blank line is one skill row. The rAthena column order is:

      MobID, Info(=MobName@SKILL_NAME), State, SkillID, SkillLv, Rate, CastTime,
      Delay, Cancelable, Target, ConditionType, ConditionValue,
      val1, val2, val3, val4, val5, Emotion, Chat

  `Chat` is dropped (cosmetic); `SkillID` is kept alongside the skill name since
  the client needs the numeric id to render the skill animation.
  Rows are grouped by mob id: positive ids under their string key (`"1001"`),
  and the three global ids under reserved keys - `-1` -> `"global_boss"`,
  `-2` -> `"global_normal"`, `-3` -> `"global_all"` - to be expanded per-mob at
  load time (`MobSkill.Db`), not baked here.

  This is a dev tool: it **fails loudly** with `{:error, {:unknown_state, tok}}`
  (or `:unknown_target` / `:unknown_condition` / `:unknown_cancelable` /
  `:unknown_mob_id`) on any token outside the rAthena header vocabulary, so drift
  from upstream surfaces immediately.

  Two rAthena numeric-field quirks are handled: `val1`/`val2` may be C-style hex
  (`0x81`, a mode bitmask on `NPC_EMOTION` rows) and the condition value may be a
  status-abnormality **name** (`hiding`, `anybad`) for the `mystatuson` /
  `friendstatuson` family - kept as an atom rather than an integer. Empty
  condition values default to `0`.

  `classify/1` backs the `mix aesir.import.mob_skills` coverage manifest: it
  mirrors `MobSkill.Selector`'s castable gate (`Skill.Catalog.by_id/1` +
  `MobSkill.Denylist`) so the manifest reports the same live truth the AI
  actually casts against.
  """

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog

  @typedoc "A parsed skill row."
  @type row :: %{
          skill: String.t(),
          skill_id: integer(),
          state: atom(),
          level: integer(),
          rate: integer(),
          cast_time: integer(),
          delay: integer(),
          cancelable: boolean(),
          target: atom(),
          condition: %{
            type: atom(),
            value: integer() | atom(),
            val1: integer() | nil,
            val2: integer() | nil,
            val3: integer() | nil,
            val4: integer() | nil,
            val5: integer() | nil
          },
          emotion: integer() | nil
        }

  @typedoc "Coverage classification for a skill id against the live skill catalog."
  @type classification :: :castable | {:denylisted, String.t()} | :unresolved

  @states ~w(any idle walk dead loot attack angry chase follow anytarget)

  @targets ~w(
    target self friend master randomtarget
    around around1 around2 around3 around4 around5 around6 around7 around8
  )

  @conditions ~w(
    always onspawn myhpltmaxrate myhpinrate mystatuson mystatusoff
    friendhpltmaxrate friendhpinrate friendstatuson friendstatusoff
    attackpcgt attackpcge slavelt slavele closedattacked longrangeattacked
    skillused afterskill casttargeted rudeattacked mobnearbygt groundattacked
    damagedgt alchemist trickcasting masterattacked
  )

  @doc """
  Parses the raw contents of `mob_skill_db.txt` into `%{mob_key => [row]}`.

  Takes the **file contents** (not a path). Rows keep file order within each mob
  key. Returns `{:error, reason}` on the first malformed line.
  """
  @spec to_rows(String.t()) :: {:ok, %{String.t() => [row()]}} | {:error, term()}
  def to_rows(contents) when is_binary(contents) do
    contents
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "//")))
    |> parse_lines()
  end

  @doc """
  Classifies `skill_id` against the live skill catalog + denylist: `:castable`
  (resolves, has an active module, not denylisted), `{:denylisted, reason}`
  (resolves but is denied), or `:unresolved` (no catalog entry / no active
  module).
  """
  @spec classify(integer()) :: classification()
  def classify(skill_id) do
    with {:ok, definition} <- SkillCatalog.by_id(skill_id),
         {:ok, _module} <- SkillCatalog.active_module_for(definition.name) do
      case Denylist.reason_for(skill_id) do
        nil -> :castable
        reason -> {:denylisted, reason}
      end
    else
      :error -> :unresolved
    end
  end

  @spec parse_lines([String.t()]) :: {:ok, %{String.t() => [row()]}} | {:error, term()}
  defp parse_lines(lines) do
    lines
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, acc} ->
      case parse_line(line) do
        {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} ->
        grouped =
          entries
          |> Enum.reverse()
          |> Enum.group_by(fn {key, _row} -> key end, fn {_key, row} -> row end)

        {:ok, grouped}

      error ->
        error
    end
  end

  @spec parse_line(String.t()) :: {:ok, {String.t(), row()}} | {:error, term()}
  defp parse_line(line) do
    fields = String.split(line, ",")

    with {:ok, key} <- parse_mob_key(Enum.at(fields, 0)),
         {:ok, state} <- fetch_token(@states, Enum.at(fields, 2), :unknown_state),
         {:ok, cancelable} <- parse_cancelable(Enum.at(fields, 8)),
         {:ok, target} <- fetch_token(@targets, Enum.at(fields, 9), :unknown_target),
         {:ok, condition_type} <-
           fetch_token(@conditions, Enum.at(fields, 10), :unknown_condition) do
      row = %{
        skill: skill_name(Enum.at(fields, 1)),
        skill_id: to_int(Enum.at(fields, 3)),
        state: state,
        level: to_int(Enum.at(fields, 4)),
        rate: to_int(Enum.at(fields, 5)),
        cast_time: to_int(Enum.at(fields, 6)),
        delay: to_int(Enum.at(fields, 7)),
        cancelable: cancelable,
        target: target,
        condition: %{
          type: condition_type,
          value: to_condition_value(Enum.at(fields, 11)),
          val1: to_int_or_nil(Enum.at(fields, 12)),
          val2: to_int_or_nil(Enum.at(fields, 13)),
          val3: to_int_or_nil(Enum.at(fields, 14)),
          val4: to_int_or_nil(Enum.at(fields, 15)),
          val5: to_int_or_nil(Enum.at(fields, 16))
        },
        emotion: to_int_or_nil(Enum.at(fields, 17))
      }

      {:ok, {key, row}}
    end
  end

  @spec parse_mob_key(String.t() | nil) :: {:ok, String.t()} | {:error, term()}
  defp parse_mob_key(raw) when is_binary(raw) do
    case Integer.parse(raw) do
      {-1, ""} -> {:ok, "global_boss"}
      {-2, ""} -> {:ok, "global_normal"}
      {-3, ""} -> {:ok, "global_all"}
      {id, ""} when id > 0 -> {:ok, Integer.to_string(id)}
      _ -> {:error, {:unknown_mob_id, raw}}
    end
  end

  defp parse_mob_key(raw), do: {:error, {:unknown_mob_id, raw}}

  @spec fetch_token([String.t()], String.t() | nil, atom()) ::
          {:ok, atom()} | {:error, {atom(), String.t() | nil}}
  defp fetch_token(allowed, token, error) do
    if token in allowed, do: {:ok, String.to_atom(token)}, else: {:error, {error, token}}
  end

  @spec parse_cancelable(String.t() | nil) :: {:ok, boolean()} | {:error, term()}
  defp parse_cancelable("yes"), do: {:ok, true}
  defp parse_cancelable("no"), do: {:ok, false}
  defp parse_cancelable(other), do: {:error, {:unknown_cancelable, other}}

  @spec skill_name(String.t()) :: String.t()
  defp skill_name(info), do: info |> String.split("@", parts: 2) |> List.last()

  @spec to_int(String.t()) :: integer()
  defp to_int(value), do: value |> String.trim() |> String.to_integer()

  @spec to_condition_value(String.t() | nil) :: integer() | atom()
  defp to_condition_value(nil), do: 0

  defp to_condition_value(value) do
    case String.trim(value) do
      "" ->
        0

      trimmed ->
        case Integer.parse(trimmed) do
          {number, ""} -> number
          _ -> String.to_atom(trimmed)
        end
    end
  end

  @spec to_int_or_nil(String.t() | nil) :: integer() | nil
  defp to_int_or_nil(nil), do: nil

  defp to_int_or_nil(value) do
    case String.trim(value) do
      "" -> nil
      "0x" <> hex -> String.to_integer(hex, 16)
      "0X" <> hex -> String.to_integer(hex, 16)
      trimmed -> String.to_integer(trimmed)
    end
  end
end
