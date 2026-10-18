defmodule Aesir.ZoneServer.Mmo.StatusEffect.StatusWriteClassificationTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../../../../lib/aesir/zone_server", __DIR__)
  @operations [
    :apply_status,
    :apply_status_with_entry,
    :store_if_newer,
    :remove_status,
    :remove_status_if_current,
    :replace_status_if_current,
    :take_status,
    :update_status,
    :clear_unit_statuses,
    :update_next_tick
  ]

  @interpreter "mmo/status_effect/interpreter.ex"
  @classified %{
    {@interpreter, :remove_current_status_and_notify, :remove_status_if_current} =>
      :remove_current_status_and_notify,
    {@interpreter, :restart_status_if_current, :replace_status_if_current} =>
      :restart_status_if_current,
    {@interpreter, :end_status, :remove_status} => :end_status,
    {@interpreter, :store_end_outcome, :replace_status_if_current} => :silent_keep,
    {@interpreter, :store_end_outcome, :remove_status_if_current} => :finish_requested_end,
    {@interpreter, :end_removed_unit_statuses, :clear_unit_statuses} => :silent_teardown,
    {@interpreter, :end_removed, :remove_status_if_current} => :finish_removal,
    {@interpreter, :store_applied_status, :apply_status_with_entry} => :finish_application,
    {@interpreter, :rollback_application, :remove_status_if_current} => :silent_unstarted,
    {@interpreter, :discard_application, :remove_status_if_current} => :silent_unstarted,
    {@interpreter, :expire_status_if_current, :remove_status_if_current} =>
      :expire_status_if_current,
    {@interpreter, :apply_committed_action_result, :replace_status_if_current} =>
      :apply_committed_action_result,
    {@interpreter, :store_movement_changes_if_current, :replace_status_if_current} =>
      :store_movement_changes_if_current,
    {@interpreter, :settle_absorb, :take_status} => :settle_absorb,
    {@interpreter, :update_link_status, :apply_status_with_entry} => :silent_values,
    {@interpreter, :store_instance_changes, :update_status} => :silent_values,
    {@interpreter, :store_instance_changes_if_current, :update_status} => :silent_values,
    {"mmo/status_effect/dispel.ex", :disarm_penalties, :update_status} => :silent_disarm,
    {"mmo/status_effect/clear_buffs.ex", :disarm_berserk, :update_status} => :silent_disarm,
    {"mmo/status_tick_manager.ex", :advance_next_tick, :replace_status_if_current} =>
      :silent_timer,
    {"mmo/status_effect/effects/poison_react.ex", :before_weapon_hit, :replace_status_if_current} =>
      :silent_values,
    {"mmo/status_effect/effects/poison_react.ex", :claim_charge, :replace_status_if_current} =>
      :silent_values,
    {"mmo/skills/professor/pf_spiderweb.ex", :extend_hold, :replace_status_if_current} =>
      :silent_values,
    {"mmo/skills/professor/pf_spiderweb.ex", :release, :replace_status_if_current} =>
      :silent_values
  }
  @silent [
    :silent_keep,
    :silent_teardown,
    :silent_unstarted,
    :silent_values,
    :silent_disarm,
    :silent_timer
  ]

  test "every storage write in the lifecycle boundary has an explicit notification disposition" do
    files = [
      "mmo/status_effect/effects/splasher.ex" | Enum.map(Map.keys(@classified), &elem(&1, 0))
    ]

    definitions =
      files
      |> Enum.uniq()
      |> Enum.flat_map(fn path ->
        path
        |> then(&File.read!(Path.join(@root, &1)))
        |> Code.string_to_quoted!()
        |> functions()
        |> Enum.map(fn {name, body} -> {path, name, body} end)
      end)

    writes =
      Enum.flat_map(definitions, fn {path, name, body} ->
        for operation <- storage_writes(body), do: {path, name, operation}
      end)

    assert Enum.frequencies(writes) == Map.new(@classified, fn {site, _} -> {site, 1} end)

    for {{path, _name, _operation}, boundary} <- @classified, boundary not in @silent do
      bodies = for {^path, ^boundary, body} <- definitions, do: body

      assert Enum.any?(bodies, &notifies?/1),
             "#{path}: #{boundary} no longer notifies after its committed write"
    end
  end

  defp functions(ast) do
    {_, definitions} =
      Macro.prewalk(ast, [], fn
        {kind, _, [head, body]} = node, acc when kind in [:def, :defp] ->
          head =
            case head do
              {:when, _, [call | _]} -> call
              call -> call
            end

          {name, _, _args} = head
          {node, [{name, body} | acc]}

        node, acc ->
          {node, acc}
      end)

    definitions
  end

  defp storage_writes(body) do
    {_, writes} =
      Macro.prewalk(body, [], fn
        {{:., _, [{:__aliases__, _, [:StatusStorage]}, operation]}, _, _args} = node, acc
        when operation in @operations ->
          {node, [operation | acc]}

        node, acc ->
          {node, acc}
      end)

    writes
  end

  defp notifies?(body) do
    {_, found?} =
      Macro.prewalk(body, false, fn
        {call, _, args} = node, found? when is_atom(call) and is_list(args) ->
          {node,
           found? or
             call in [
               :notify_mob_status_write,
               :notify_unit_status_applied,
               :notify_unit_status_removed
             ]}

        node, found? ->
          {node, found?}
      end)

    found?
  end
end
