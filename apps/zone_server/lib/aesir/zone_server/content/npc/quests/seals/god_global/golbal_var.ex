defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.GodGlobal.GolbalVar do
  @moduledoc """
  GM-only console for inspecting and repairing the God Item seal quest variables.

  ## Behavior

  - Only GM level 99 characters can use it, and every action asks for the GM password.
  - Shows the four server-wide seal counters, sets one of them to a value up to the release
    threshold, or resets all four to zero.
  - Sets one of the player's own seal quest progress variables to any number.
  - On server start, sets the seal thresholds: 25 to appear and 50 to release in renewal,
    50 and 100 in pre-renewal.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "sec_in02", x: 15, y: 170, dir: 0, sprite: 817, name: "Golbal var", scope: :shared}
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FGmNpc
  alias Aesir.ZoneServer.Script.Rathena

  @password_check [68_392_411, 0]
  @quest_vars ~w(god_sl_1 god_eremes god_brising god_mjo_0 god_mjo_1 god_mjo_2 god_mjo_3 god_mjo_4)

  @impl true
  def on_event("OnInit", ctx) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      ctx |> set_server_temp_var("god_check1", 25) |> set_server_temp_var("god_check2", 50)
    else
      ctx |> set_server_temp_var("god_check1", 50) |> set_server_temp_var("god_check2", 100)
    end
  end

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FGmNpc.call(ctx, [])

    {ctx, password} =
      ctx
      |> mes("[Check]")
      |> mes("Please enter the password.")
      |> next()
      |> FGmNpc.call(@password_check)

    if password == 1 do
      {ctx, choice} =
        ctx
        |> mes("[Check]")
        |> mes("Please choose a menu.")
        |> next()
        |> select(["Now", "No.1", "No.2", "No.3", "No.4", "Reset" | @quest_vars])

      menu(ctx, choice)
    else
      ctx |> mes("[Check]") |> mes("Incorrect password.") |> close()
    end
  end

  defp menu(ctx, 1), do: ctx |> show_seal_counters() |> close()

  defp menu(ctx, choice) when choice in 2..5 do
    {ctx, _} = scoped_call(ctx, ["$God#{choice - 1}"], &change_seal_counter/2)
    ctx
  end

  defp menu(ctx, 6), do: reset_seal_counters(ctx)

  defp menu(ctx, choice) when choice in 7..14 do
    {ctx, _} = scoped_call(ctx, [Enum.at(@quest_vars, choice - 7)], &change_quest_var/2)
    ctx
  end

  defp menu(ctx, _), do: ctx

  defp reset_seal_counters(ctx) do
    {ctx, password} =
      ctx
      |> mes("[Check]")
      |> mes("Are you really sure that you want to reset the entire list of God Globalvar?")
      |> mes("Please enter the password.")
      |> next()
      |> FGmNpc.call(@password_check)

    if password == 1 do
      ctx
      |> mes("[Check]")
      |> mes("Now, the entire list of God Globalvar is being reset.")
      |> next()
      |> set_server_var("God1", 0)
      |> set_server_var("God2", 0)
      |> set_server_var("God3", 0)
      |> set_server_var("God4", 0)
      |> show_seal_counters()
      |> close()
    else
      cancel(ctx)
    end
  end

  defp show_seal_counters(ctx) do
    Enum.reduce(1..4, ctx, fn seal, ctx ->
      value = get_server_var(ctx, "God#{seal}", 0)
      mes(ctx, "^0000FF$God#{seal}^000000 = ^FF0000#{value}^000000.")
    end)
  end

  defp change_seal_counter(ctx, [var]) do
    {ctx, typed} = input(ctx, :int)
    {_, value} = Rathena.input_int(typed, 0, get_server_temp_var(ctx, "god_check2", 0))

    {ctx, password} =
      ctx
      |> mes("[Check]")
      |> mes("Would you like to change to #{value}?")
      |> mes("Please enter the password.")
      |> next()
      |> FGmNpc.call(@password_check)

    if password == 1 do
      ctx =
        ctx
        |> mes("[Check]")
        |> mes("The command #{value} has been confirmed.")
        |> next()
        |> setd(var, value)
        |> mes("#{var} #{value}")
        |> close()

      {ctx, nil}
    else
      {cancel(ctx), nil}
    end
  end

  defp change_quest_var(ctx, [var]) do
    {ctx, value} = input(ctx, :int)

    ctx =
      ctx
      |> setd(var, value)
      |> next()
      |> mes("[Check]")
      |> mes("Done.")
      |> close()

    {ctx, nil}
  end

  defp cancel(ctx), do: ctx |> mes("[Check]") |> mes("The command has been canceled.") |> close()
end
