defmodule Aesir.ZoneServer.Script.Dsl.Variables do
  @moduledoc """
  Variable-scope buildins for the script DSL: permanent char vars, session
  temp vars, server (persistent and temp) vars, account vars, NPC vars,
  script-local vars, and the dynamic `getd`/`setd` scope dispatch.

  Named `Variables` to avoid clashing with the `Aesir.ZoneServer.Script.Vars`
  storage satellite it wraps. Imported into scripts via the
  `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal, only: [apply_op: 2, no_player!: 1]

  require Logger

  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Script.Todo
  alias Aesir.ZoneServer.Script.Vars

  @doc """
  Reads the permanent char variable `key`, defaulting an unset var to `default`
  (`0` matching rAthena). Keys are atoms in scripts, stored string-keyed in the
  jsonb-backed `vars` map, so the lookup normalizes the atom to a string.
  """
  @spec get_char_var(Ctx.t(), atom(), term()) :: term()
  def get_char_var(ctx, key, default \\ 0)
  def get_char_var(%Ctx{game_state: nil}, _key, _default), do: no_player!("get_char_var/3")

  def get_char_var(%Ctx{game_state: gs}, key, default) do
    Map.get(gs.vars, to_string(key), default)
  end

  @doc """
  Sets the permanent char variable `key` to `value` through the session seam,
  which mutates `PlayerState.vars` and persists `%{vars: vars}` async. Never
  fails. The key is stringified at the jsonb boundary.
  """
  @spec set_char_var(Ctx.t(), atom(), term()) :: Ctx.t()
  def set_char_var(%Ctx{status: {:error, _}} = ctx, _key, _value), do: ctx
  def set_char_var(%Ctx{} = ctx, key, value), do: apply_op(ctx, {:set_char_var, key, value})

  @doc """
  Reads the session temp variable `key` (rAthena `@var`), defaulting an unset
  var to `default` (`0` matching rAthena). Temp vars live on `PlayerState` for
  the session's lifetime and are never persisted.
  """
  @spec get_temp_var(Ctx.t(), atom(), term()) :: term()
  def get_temp_var(ctx, key, default \\ 0)
  def get_temp_var(%Ctx{game_state: nil}, _key, _default), do: no_player!("get_temp_var/3")

  def get_temp_var(%Ctx{game_state: gs}, key, default) do
    Map.get(gs.temp_vars, to_string(key), default)
  end

  @doc """
  Sets the session temp variable `key` to `value` through the session seam.
  Never fails and never persists; the var vanishes on logout.
  """
  @spec set_temp_var(Ctx.t(), atom(), term()) :: Ctx.t()
  def set_temp_var(%Ctx{status: {:error, _}} = ctx, _key, _value), do: ctx
  def set_temp_var(%Ctx{} = ctx, key, value), do: apply_op(ctx, {:set_temp_var, key, value})

  @doc """
  Reads the `$` server permanent variable `name` (server-wide, Postgres-backed),
  defaulting an unset var to `default` (`0` matching rAthena).
  """
  @spec get_server_var(Ctx.t(), String.t(), term()) :: term()
  def get_server_var(ctx, name, default \\ 0)
  def get_server_var(%Ctx{}, name, default), do: Vars.get_server(name, default)

  @doc """
  Sets the `$` server permanent variable `name` to `value`, persisted
  write-through and visible to every server sharing the database. Never fails.
  """
  @spec set_server_var(Ctx.t(), String.t(), term()) :: Ctx.t()
  def set_server_var(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx

  def set_server_var(%Ctx{} = ctx, name, value) do
    Vars.put_server(name, value)
    ctx
  end

  @doc """
  Reads the `$@` server temp variable `name` (server-wide, in-memory), defaulting
  an unset var to `default`. Cleared on server restart.
  """
  @spec get_server_temp_var(Ctx.t(), String.t(), term()) :: term()
  def get_server_temp_var(ctx, name, default \\ 0)
  def get_server_temp_var(%Ctx{}, name, default), do: Vars.get_server_temp(name, default)

  @doc "Sets the `$@` server temp variable `name` to `value`. Never persists."
  @spec set_server_temp_var(Ctx.t(), String.t(), term()) :: Ctx.t()
  def set_server_temp_var(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx

  def set_server_temp_var(%Ctx{} = ctx, name, value) do
    Vars.put_server_temp(name, value)
    ctx
  end

  @doc """
  Reads the account variable `name` (rAthena `#`/`##`, keyed by the attached
  account), defaulting an unset var — or a player-less context — to `default`.
  The `name` carries its scope sigil so `#foo` and `##foo` stay distinct.
  """
  @spec get_account_var(Ctx.t(), String.t(), term()) :: term()
  def get_account_var(ctx, name, default \\ 0)
  def get_account_var(%Ctx{account_id: nil}, _name, default), do: default

  def get_account_var(%Ctx{account_id: account_id}, name, default),
    do: Vars.get_account(account_id, name, default)

  @doc """
  Sets the account variable `name` to `value`, persisted write-through against
  the attached account. A no-op (never fails) when no player is attached.
  """
  @spec set_account_var(Ctx.t(), String.t(), term()) :: Ctx.t()
  def set_account_var(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx
  def set_account_var(%Ctx{account_id: nil} = ctx, _name, _value), do: ctx

  def set_account_var(%Ctx{account_id: account_id} = ctx, name, value) do
    Vars.put_account(account_id, name, value)
    ctx
  end

  @doc """
  Reads the `.` NPC variable `name` (shared across every placement of the
  running NPC script, server-lifetime, in-memory), defaulting an unset var to
  `default`.
  """
  @spec get_npc_var(Ctx.t(), String.t(), term()) :: term()
  def get_npc_var(ctx, name, default \\ 0)
  def get_npc_var(%Ctx{source: source}, name, default), do: Vars.get_npc(source, name, default)

  @doc "Sets the `.` NPC variable `name` to `value`. Never persists."
  @spec set_npc_var(Ctx.t(), String.t(), term()) :: Ctx.t()
  def set_npc_var(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx

  def set_npc_var(%Ctx{source: source} = ctx, name, value) do
    Vars.put_npc(source, name, value)
    ctx
  end

  @doc """
  Reads another NPC's `.` variable by NPC name (rAthena `getvariableofnpc`).
  Resolves `npc_name` through `Npc.Registry.by_name/1` (first placement) and
  reads the variable keyed by that NPC's source tag; an unresolved name
  returns `default`. Pure read, valid on both an attached and a detached ctx.
  """
  @spec get_npc_var_of(Ctx.t(), String.t(), String.t(), term()) :: term()
  def get_npc_var_of(%Ctx{}, name, npc_name, default \\ 0) do
    case NpcRegistry.by_name(npc_name) do
      [{module, _placement} | _] -> Vars.get_npc({:npc, module.npc_id()}, name, default)
      [] -> default
    end
  end

  @doc """
  Writes another NPC's `.` variable by NPC name (rAthena `getvariableofnpc` as
  an assignment target). Resolves `npc_name` through `Npc.Registry.by_name/1`
  and writes the variable keyed by that NPC's source tag; an unresolved name
  logs a warning and no-ops. Never persists.
  """
  @spec set_npc_var_of(Ctx.t(), String.t(), String.t(), term()) :: Ctx.t()
  def set_npc_var_of(%Ctx{status: {:error, _}} = ctx, _name, _npc_name, _value), do: ctx

  def set_npc_var_of(%Ctx{} = ctx, name, npc_name, value) do
    case NpcRegistry.by_name(npc_name) do
      [{module, _placement} | _] -> Vars.put_npc({:npc, module.npc_id()}, name, value)
      [] -> Logger.warning("npc getvariableofnpc: unknown npc #{inspect(npc_name)}")
    end

    ctx
  end

  @doc """
  Reads a variable whose full name — scope sigil and optional `[N]` array
  element — is only known at runtime (rAthena `getd("…")`). The name
  dispatches to the same backing store as static access, so a dynamically
  built name reads exactly what a statically written one would. Unset whole
  vars default to `0`/`""` by the name's trailing `$`; indexed names read the
  element (padding when the base holds a non-list). Instance scope (`'`) has
  no store and raises via `Todo`, matching static instance access.
  """
  @spec getd(Ctx.t(), String.t()) :: term()
  def getd(%Ctx{} = ctx, name) do
    {scope, key, index} = Vars.parse_name(name)
    read_scope(ctx, scope, key, index)
  end

  @doc """
  Writes a variable whose full name — scope sigil and optional `[N]` array
  element — is only known at runtime (rAthena `setd "name", value`). The name
  dispatches to the same stores as static writes. An indexed name updates the
  element (padding the gap with `0`/`""` by the name's string marker); a list
  value writes consecutive elements from the index (rAthena
  `setarray getd(…), …`); a plain name replaces the whole value. The optional
  rAthena `char_id` argument is dropped. Instance scope (`'`) has no store and
  raises via `Todo`, matching static instance access.
  """
  @spec setd(Ctx.t(), String.t(), term()) :: Ctx.t()
  def setd(%Ctx{status: {:error, _}} = ctx, _name, _value), do: ctx

  def setd(%Ctx{} = ctx, name, value) do
    {scope, key, index} = Vars.parse_name(name)
    write_scope(ctx, scope, key, index, value)
  end

  # -- dynamic-variable helpers ------------------------------------------------
  #
  # The `:local`, `:temp` and `:char` scopes convert the runtime variable name to
  # an atom because those var maps are atom-keyed, which sobelow flags as
  # `DOS.StringToAtom`. Names come from server-authored NPC scripts, but a script
  # that built one from a player `input` could grow the atom table, so the skips
  # below record accepted risk rather than a false positive.
  # `String.to_existing_atom` is not a drop-in fix - a script's first write to a
  # new variable would fail; removing the risk means re-keying those maps by string.

  defp read_scope(_ctx, :server, key, index),
    do: read_dyn(Vars.get_server(key, dyn_default(key, index)), index, key)

  defp read_scope(_ctx, :server_temp, key, index),
    do: read_dyn(Vars.get_server_temp(key, dyn_default(key, index)), index, key)

  defp read_scope(ctx, :account, key, index), do: read_account(ctx, key, index)
  defp read_scope(ctx, :account_global, key, index), do: read_account(ctx, key, index)

  defp read_scope(ctx, :npc, key, index),
    do: read_dyn(Vars.get_npc(ctx.source, key, dyn_default(key, index)), index, key)

  # sobelow_skip ["DOS.StringToAtom"]
  defp read_scope(ctx, :local, key, index),
    do: read_dyn(Map.get(ctx.vars, String.to_atom(key), dyn_default(key, index)), index, key)

  defp read_scope(ctx, :temp, key, index),
    do: read_player_var(ctx, key, index, &get_temp_var/3)

  defp read_scope(ctx, :char, key, index),
    do: read_player_var(ctx, key, index, &get_char_var/3)

  defp read_scope(_ctx, :instance, key, _index), do: Todo.call!(:instance_var, [key])

  defp write_scope(ctx, :server, key, index, value) do
    Vars.put_server(key, array_write(Vars.get_server(key, []), index, value, key))
    ctx
  end

  defp write_scope(ctx, :server_temp, key, index, value) do
    Vars.put_server_temp(key, array_write(Vars.get_server_temp(key, []), index, value, key))
    ctx
  end

  defp write_scope(ctx, :account, key, index, value), do: set_account(ctx, key, index, value)

  defp write_scope(ctx, :account_global, key, index, value),
    do: set_account(ctx, key, index, value)

  defp write_scope(ctx, :npc, key, index, value) do
    Vars.put_npc(
      ctx.source,
      key,
      array_write(Vars.get_npc(ctx.source, key, []), index, value, key)
    )

    ctx
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp write_scope(ctx, :local, key, index, value) do
    set_local(
      ctx,
      String.to_atom(key),
      array_write(Map.get(ctx.vars, String.to_atom(key), []), index, value, key)
    )
  end

  defp write_scope(ctx, :temp, key, index, value),
    do: write_player_var(ctx, key, index, value, :temp)

  defp write_scope(ctx, :char, key, index, value),
    do: write_player_var(ctx, key, index, value, :char)

  defp write_scope(_ctx, :instance, key, _index, _value) do
    Todo.call!(:instance_var, [key])
  end

  defp read_account(%Ctx{account_id: nil}, key, index), do: dyn_default(key, index)

  defp read_account(%Ctx{account_id: account_id}, key, index),
    do: read_dyn(Vars.get_account(account_id, key, dyn_default(key, index)), index, key)

  # Player-scope reads (`@`/bare) raise without a player, like the static
  # `get_temp_var`/`get_char_var` reads they delegate to.
  defp read_player_var(%Ctx{game_state: nil}, _key, _index, _fun), do: no_player!("getd/2")

  # sobelow_skip ["DOS.StringToAtom"]
  defp read_player_var(%Ctx{} = ctx, key, index, fun),
    do: read_dyn(fun.(ctx, String.to_atom(key), dyn_default(key, index)), index, key)

  # Player-scope writes (`@`/bare) route through the session seam; without a
  # player they halt `:no_player` like the static `set_temp_var`/`set_char_var`.
  defp write_player_var(%Ctx{game_state: nil} = ctx, _key, _index, _value, _scope),
    do: Ctx.halt(ctx, :no_player)

  # sobelow_skip ["DOS.StringToAtom"]
  defp write_player_var(%Ctx{game_state: gs} = ctx, key, index, value, scope) do
    current = Map.get(player_scope(gs, scope), key, [])

    case scope do
      :temp -> set_temp_var(ctx, String.to_atom(key), array_write(current, index, value, key))
      :char -> set_char_var(ctx, String.to_atom(key), array_write(current, index, value, key))
    end
  end

  defp player_scope(%{temp_vars: temp_vars}, :temp), do: temp_vars
  defp player_scope(%{vars: vars}, :char), do: vars

  # Whole-var reads default `0`/`""` by the string marker; indexed reads base
  # the array access on an empty list.
  defp dyn_default(key, nil), do: dyn_pad(key)
  defp dyn_default(_key, _index), do: []

  defp dyn_pad(key) when is_binary(key),
    do: if(String.ends_with?(key, "$"), do: "", else: 0)

  defp read_dyn(current, nil, _key), do: current

  defp read_dyn(current, index, key) do
    if is_list(current), do: Enum.at(current, index, dyn_pad(key)), else: dyn_pad(key)
  end

  # Indexed writes pad the gap (`0`/`""` by the string marker); a list value
  # writes consecutive elements from the index (rAthena setarray-through-getd),
  # a scalar a single element. A non-list base is treated as an empty array.
  defp array_write(_current, nil, value, _key), do: value

  defp array_write(current, index, value, key) do
    current = if is_list(current), do: current, else: []
    pad = dyn_pad(key)

    if is_list(value) do
      Rathena.put_many(current, index, value, pad)
    else
      Rathena.put_at(current, index, value, pad)
    end
  end

  defp set_account(%Ctx{account_id: nil} = ctx, _key, _index, _value), do: ctx

  defp set_account(%Ctx{account_id: account_id} = ctx, key, index, value) do
    Vars.put_account(
      account_id,
      key,
      array_write(Vars.get_account(account_id, key, []), index, value, key)
    )

    ctx
  end

  @doc """
  Sets the script-local variable `key` (rAthena `.@var`). Pure Ctx update; the
  value lives only for the duration of the running script.
  """
  @spec set_local(Ctx.t(), atom(), term()) :: Ctx.t()
  def set_local(%Ctx{status: {:error, _}} = ctx, _key, _value), do: ctx
  def set_local(%Ctx{vars: vars} = ctx, key, value), do: %{ctx | vars: Map.put(vars, key, value)}

  @doc """
  Reads the script-local variable `key`, defaulting an unset var to `default`
  (`0` matching rAthena).
  """
  @spec get_local(Ctx.t(), atom(), term()) :: term()
  def get_local(%Ctx{vars: vars}, key, default \\ 0), do: Map.get(vars, key, default)
end
