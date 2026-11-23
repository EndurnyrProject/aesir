defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.UnidentifiedMachine11780 do
  @moduledoc """
  Offers item repairs after the airship ticket quest progresses.

  ## Behavior

  - Counts damaged items before offering to repair them.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 117,
        y: 80,
        dir: 5,
        sprite: 111,
        name: "Unidentified Machine",
        scope: :shared,
        unique_name: "Unidentified Machine#as"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :kain_ticket, 0) > 12 do
      offer_repairs(ctx)
    else
      ctx
      |> mes("^3355FFIt's some sort of")
      |> mes("strange machine.")
      |> mes("Its function and purpose")
      |> mes("is completely undiscernable.^000000")
      |> close()
    end
  end

  defp offer_repairs(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("This is the")
      |> mes("^FF0000Expert Repairman^000000?!")
      |> mes("It looks like it")
      |> mes("needs repairs itself...")
      |> next()
      |> select(["Fix an Item", "Cancel."])

    if choice == 1, do: inspect_damage(ctx), else: cancel(ctx)
  end

  defp inspect_damage(ctx) do
    if getbrokenid(ctx, 1) == 0 do
      ctx |> mes("*Beep-*") |> mes("You have") |> mes("nothing to fix.") |> close()
    else
      ctx = ctx |> todo(:getinventorylist, []) |> set_local(:i, 0) |> count_damage()

      {ctx, choice} =
        ctx
        |> mes("*Beep-*")
        |> mes("You have a total")
        |> mes("of #{get_local(ctx, :total, 0)} damaged items.")
        |> mes("Shall I repair them?")
        |> next()
        |> select(["Yes", "No"])

      if choice == 1, do: repair_items(ctx), else: cancel(ctx)
    end
  end

  defp repair_items(ctx) do
    ctx = ctx |> todo(:getinventorylist, []) |> set_local(:i, 0) |> recount_damage()

    ctx =
      if get_local(ctx, :total, 0) == get_local(ctx, :total2, 0) do
        ctx |> repairall() |> mes("*Beep-*") |> mes("Repair complete.")
      else
        ctx |> mes("*Beep-*") |> mes("Please check") |> mes("your items again.")
      end

    close(ctx)
  end

  defp cancel(ctx), do: ctx |> mes("You have chosen to stop.") |> close()

  defp count_damage(ctx) do
    if get_local(ctx, :i, 0) < get_temp_var(ctx, :inventorylist_count, 0) do
      ctx =
        set_local(
          ctx,
          :total,
          get_local(ctx, :total, 0) +
            Enum.at(get_temp_var(ctx, :inventorylist_attribute, []), get_local(ctx, :i, 0), 0)
        )

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> count_damage()
    else
      ctx
    end
  end

  defp recount_damage(ctx) do
    if get_local(ctx, :i, 0) < get_temp_var(ctx, :inventorylist_count, 0) do
      ctx =
        set_local(
          ctx,
          :total2,
          get_local(ctx, :total2, 0) +
            Enum.at(get_temp_var(ctx, :inventorylist_attribute, []), get_local(ctx, :i, 0), 0)
        )

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> recount_damage()
    else
      ctx
    end
  end
end
