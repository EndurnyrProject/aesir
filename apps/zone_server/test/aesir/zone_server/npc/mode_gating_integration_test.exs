defmodule Aesir.ZoneServer.Npc.ModeGatingIntegrationTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Npc.SessionDynamicSupervisor
  alias Aesir.ZoneServer.Npc.Transpiler

  @map "zzz_task8_mode_gating_map"
  @fanout_name "ZzzTask8ModeGatingFanout"
  @shared_label "OnZzzTask8SharedGate"
  @renewal_label "OnZzzTask8RenewalGate"
  @pre_renewal_label "OnZzzTask8PreRenewalGate"

  @shared_module Aesir.ZoneServer.Content.Npc.Floating.Zzztask8modegatingsharedbody
  @renewal_module Aesir.ZoneServer.Content.Npc.Re.ZzzTask8ModeGating.RenewalOnly.RenewalOnly
  @pre_renewal_module Aesir.ZoneServer.Content.Npc.PreRe.ZzzTask8ModeGating.PreRenewalOnly.PreRenewalOnly
  @generated_modules [@shared_module, @renewal_module, @pre_renewal_module]
  @session_supervisor_key {SessionDynamicSupervisor, :server}
  @session_tables [:npc_session_flags, :npc_display_overrides]

  @tag :tmp_dir
  test "generated NPCs expose only the shared and active-mode registry composition", %{
    tmp_dir: tmp_dir
  } do
    rathena_root = Path.join(tmp_dir, "rathena")
    out_root = Path.join(tmp_dir, "out")
    previous_registry = :persistent_term.get(Registry, :missing)
    previous_session_supervisor = process_dictionary_entry(@session_supervisor_key)
    global_session_supervisor = Process.whereis(SessionDynamicSupervisor)

    assert is_pid(global_session_supervisor)

    global_session_children = session_children(global_session_supervisor)
    session_tables = session_tables_snapshot()

    test_session_supervisor =
      start_supervised!({DynamicSupervisor, strategy: :one_for_one, name: nil})

    try do
      Process.put(@session_supervisor_key, test_session_supervisor)

      on_exit(fn ->
        restore_registry(previous_registry)
        File.rm_rf!(rathena_root)
        File.rm_rf!(out_root)

        assert :persistent_term.get(Registry, :missing) == previous_registry
        refute File.exists?(rathena_root)
        refute File.exists?(out_root)
      end)

      on_exit(fn -> unload_modules(@generated_modules) end)
      unload_modules(@generated_modules)

      write_fixture!(rathena_root)

      result = Transpiler.run(rathena_root, out_root: out_root)

      assert result.failures == []
      assert result.orphan_duplicates == []

      generated_paths = Enum.map(result.written, &Path.join(out_root, &1))

      assert Enum.sort(Enum.map(generated_paths, &Path.extname/1)) == [".ex", ".ex", ".ex"]
      assert File.exists?(Path.join(out_root, "priv/npc_transpile/manifest.json"))

      generated_modules = Enum.map(generated_paths, &generated_module!/1)
      assert MapSet.new(generated_modules) == MapSet.new(@generated_modules)
      Enum.each(generated_modules, &refute(Code.ensure_loaded?(&1)))

      compiled_modules =
        Enum.flat_map(generated_paths, fn path ->
          path
          |> Code.compile_file()
          |> Enum.map(&elem(&1, 0))
        end)

      on_exit(fn -> unload_modules(compiled_modules) end)

      assert MapSet.new(compiled_modules) == MapSet.new(generated_modules)

      assert Map.new(generated_modules, &{&1, &1.content_scope()}) == %{
               @shared_module => :shared,
               @renewal_module => :renewal,
               @pre_renewal_module => :pre_renewal
             }

      all_entries =
        Map.new(@generated_modules, fn module ->
          {module, Map.new(module.spawn(), &{&1.x, &1})}
        end)

      assert placement_scopes(all_entries) == %{
               10 => :shared,
               20 => :renewal,
               21 => :renewal,
               30 => :pre_renewal,
               31 => :pre_renewal,
               40 => :renewal,
               50 => :pre_renewal
             }

      assert_mode(compiled_modules, all_entries, %{
        mode: :renewal,
        active_xs: [10, 20, 21, 40],
        inactive_xs: [30, 31, 50],
        fanout_xs: [10, 20, 21],
        active_exclusive_module: @renewal_module,
        active_exclusive_name: "ZzzTask8ModeGatingRenewalOnly",
        inactive_exclusive_name: "ZzzTask8ModeGatingPreRenewalOnly",
        active_exclusive_label: @renewal_label,
        inactive_exclusive_label: @pre_renewal_label
      })

      assert_mode(compiled_modules, all_entries, %{
        mode: :pre_renewal,
        active_xs: [10, 30, 31, 50],
        inactive_xs: [20, 21, 40],
        fanout_xs: [10, 30, 31],
        active_exclusive_module: @pre_renewal_module,
        active_exclusive_name: "ZzzTask8ModeGatingPreRenewalOnly",
        inactive_exclusive_name: "ZzzTask8ModeGatingRenewalOnly",
        active_exclusive_label: @pre_renewal_label,
        inactive_exclusive_label: @renewal_label
      })
    after
      restore_process_dictionary(@session_supervisor_key, previous_session_supervisor)

      assert process_dictionary_entry(@session_supervisor_key) == previous_session_supervisor
      assert session_children(global_session_supervisor) == global_session_children
      assert session_tables_snapshot() == session_tables
    end
  end

  defp assert_mode(modules, all_entries, expected) do
    Registry.reload(modules, expected.mode)

    assert entry_xs(Registry.entries()) == expected.active_xs

    Enum.each(expected.active_xs, fn x ->
      {module, placement} = entry_at(all_entries, x)
      gid = Registry.entity_id(placement)

      assert {:ok, {^module, ^placement}} = Registry.module_at(@map, x, x)
      assert {:ok, {^module, ^placement}} = Registry.module_for_unit(gid)
    end)

    Enum.each(expected.inactive_xs, fn x ->
      {_module, placement} = entry_at(all_entries, x)

      assert :error = Registry.module_at(@map, x, x)
      assert :error = Registry.module_for_unit(Registry.entity_id(placement))
    end)

    assert Registry.by_name(@fanout_name) |> entry_xs() == expected.fanout_xs

    active_exclusive_module = expected.active_exclusive_module

    assert [{^active_exclusive_module, _placement}] =
             Registry.by_name(expected.active_exclusive_name)

    assert Registry.by_name(expected.inactive_exclusive_name) == []

    assert Enum.sort(Registry.labels()) ==
             Enum.sort(["OnInit", @shared_label, expected.active_exclusive_label])

    assert label_xs("OnInit") == expected.active_xs
    assert label_xs(@shared_label) == expected.fanout_xs
    assert label_xs(expected.active_exclusive_label) == [List.last(expected.active_xs)]
    assert Registry.entries_for_label(expected.inactive_exclusive_label) == []
    assert Registry.gids_for_label(expected.inactive_exclusive_label) == []

    assert Registry.touch_rects(@map)
           |> Enum.map(fn {gid, x_range, y_range} ->
             assert {:ok, {_module, placement}} = Registry.module_for_unit(gid)
             assert x_range == (placement.x - 1)..(placement.x + 1)
             assert y_range == (placement.y - 1)..(placement.y + 1)
             placement.x
           end)
           |> Enum.sort() == expected.active_xs
  end

  defp entry_at(all_entries, x) do
    Enum.find_value(all_entries, fn {module, placements} ->
      if placement = placements[x], do: {module, placement}
    end)
  end

  defp entry_xs(entries) do
    entries
    |> Enum.map(fn {_module, placement} -> placement.x end)
    |> Enum.sort()
  end

  defp placement_scopes(entries) do
    entries
    |> Map.values()
    |> Enum.flat_map(&Map.values/1)
    |> Map.new(&{&1.x, &1.scope})
  end

  defp label_xs(label) do
    label
    |> Registry.entries_for_label()
    |> Enum.map(fn {module, gid} ->
      assert {:ok, {^module, placement}} = Registry.module_for_unit(gid)
      placement.x
    end)
    |> Enum.sort()
  end

  defp generated_module!(path) do
    {:ok, {:defmodule, _, [{:__aliases__, _, segments}, _]}} =
      path |> File.read!() |> Code.string_to_quoted()

    Module.concat(segments)
  end

  defp session_children(supervisor) do
    supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.sort()
  end

  defp session_tables_snapshot do
    Map.new(@session_tables, fn table -> {table, table |> :ets.tab2list() |> Enum.sort()} end)
  end

  defp unload_modules(modules) do
    Enum.each(modules, fn module ->
      :code.delete(module)
      :code.purge(module)
      refute :code.is_loaded(module)
      refute :erlang.check_old_code(module)
    end)
  end

  defp process_dictionary_entry(key) do
    if key in Process.get_keys(), do: {:present, Process.get(key)}, else: :missing
  end

  defp restore_process_dictionary(key, :missing), do: Process.delete(key)
  defp restore_process_dictionary(key, {:present, value}), do: Process.put(key, value)

  defp restore_registry(:missing), do: :persistent_term.erase(Registry)
  defp restore_registry(registry), do: :persistent_term.put(Registry, registry)

  defp write_fixture!(root) do
    write!(root, "npc/re/scripts_main.conf", """
    import: npc/zzz_task8_mode_gating/shared.conf
    import: npc/re/zzz_task8_mode_gating/enabled.conf
    """)

    write!(root, "npc/pre-re/scripts_main.conf", """
    import: npc/zzz_task8_mode_gating/shared.conf
    import: npc/pre-re/zzz_task8_mode_gating/enabled.conf
    """)

    write!(root, "npc/zzz_task8_mode_gating/shared.conf", """
    npc: npc/zzz_task8_mode_gating/shared.txt
    """)

    write!(root, "npc/re/zzz_task8_mode_gating/enabled.conf", """
    npc: npc/re/zzz_task8_mode_gating/placements.txt
    npc: npc/re/zzz_task8_mode_gating/renewal_only.txt
    """)

    write!(root, "npc/pre-re/zzz_task8_mode_gating/enabled.conf", """
    npc: npc/pre-re/zzz_task8_mode_gating/placements.txt
    npc: npc/pre-re/zzz_task8_mode_gating/pre_renewal_only.txt
    """)

    write!(root, "npc/zzz_task8_mode_gating/shared.txt", """
    -\tscript\t::ZzzTask8ModeGatingSharedBody\t-1,{
    end;

    OnInit:
    end;

    #{@shared_label}:
    end;
    }
    #{@map},10,10,4\tduplicate(ZzzTask8ModeGatingSharedBody)\tShared#task8::#{@fanout_name}\t54,1,1
    """)

    write!(root, "npc/re/zzz_task8_mode_gating/placements.txt", """
    #{@map},20,20,4\tduplicate(ZzzTask8ModeGatingSharedBody)\tRenewalA#task8::#{@fanout_name}\t54,1,1
    #{@map},21,21,4\tduplicate(ZzzTask8ModeGatingSharedBody)\tRenewalB#task8::#{@fanout_name}\t54,1,1
    """)

    write!(root, "npc/pre-re/zzz_task8_mode_gating/placements.txt", """
    #{@map},30,30,4\tduplicate(ZzzTask8ModeGatingSharedBody)\tPreRenewalA#task8::#{@fanout_name}\t54,1,1
    #{@map},31,31,4\tduplicate(ZzzTask8ModeGatingSharedBody)\tPreRenewalB#task8::#{@fanout_name}\t54,1,1
    """)

    write!(root, "npc/re/zzz_task8_mode_gating/renewal_only.txt", """
    #{@map},40,40,4\tscript\tRenewal Only#task8::ZzzTask8ModeGatingRenewalOnly\t54,1,1,{
    end;

    OnInit:
    end;

    #{@renewal_label}:
    end;
    }
    """)

    write!(root, "npc/pre-re/zzz_task8_mode_gating/pre_renewal_only.txt", """
    #{@map},50,50,4\tscript\tPre-Renewal Only#task8::ZzzTask8ModeGatingPreRenewalOnly\t54,1,1,{
    end;

    OnInit:
    end;

    #{@pre_renewal_label}:
    end;
    }
    """)
  end

  defp write!(root, relative, contents) do
    path = Path.join(root, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end
end
