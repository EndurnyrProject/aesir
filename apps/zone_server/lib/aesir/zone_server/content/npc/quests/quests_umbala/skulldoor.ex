defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.Skulldoor do
  @moduledoc """
  Guards the shaman's door with a gemstone puzzle.

  ## Behavior

  - Admits visitors who have progressed far enough in the quest directly.
  - Lets others try gemstones in the skull's sockets for a chance to enter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - sabernet09
    - rAthena Team
    - x[tsk]
    - Lupus
    - PoW
    - Evera
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "umbala",
        x: 221,
        y: 193,
        dir: 1,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#Skulldoor"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 7 do
      warp(ctx, "um_in", 32, 71)
    else
      {ctx, choice} =
        ctx
        |> mes("^3355FFA human skull disturbingly")
        |> mes("hangs beside the door. The door is")
        |> mes("locked tight, so you can't get in.")
        |> mes("As you peer through the keyhole,")
        |> mes("you can see somebody moving inside the room.^000000")
        |> next()
        |> select(["Examine the skull.", "Quit."])

      if choice == 1, do: examine_skull(ctx), else: pass_door(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp pass_door(ctx) do
    ctx
    |> mes("^3355FFYou decided to pass by the door.")
    |> mes("It looks like it might be too hard to open.^000000")
    |> close()
  end

  defp examine_skull(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou see that the eye sockets")
      |> mes("of the skull are empty.")
      |> mes("How peculiar...")
      |> mes("It seems that Gemstones")
      |> mes("would fit perfectly inside of")
      |> mes("them.^000000")
      |> next()

    with {:ok, ctx} <- socket(ctx, :left),
         {:ok, ctx} <- socket(ctx, :right) do
      try_door(ctx)
    else
      {:cancel, ctx} -> ctx
    end
  end

  defp socket(ctx, side) do
    {ctx, prompt} =
      case side do
        :left ->
          {mes(ctx, "^3355FFYou see the left eye socket of the"),
           "skull. What do you want to do?^000000"}

        :right ->
          {mes(ctx, "^3355FFYou see the right eye socket of"),
           "the skull. What do you want to do?^000000"}
      end

    {ctx, choice} =
      ctx
      |> mes(prompt)
      |> next()
      |> select([
        "Leave it as it is.",
        "Insert a Blue Gemstone.",
        "Insert a Yellow Gemstone.",
        "Insert a Red Gemstone."
      ])

    case choice do
      1 ->
        ctx = ctx |> mes("^3355FFYou left the eye socket as it was.^000000") |> next()
        {:ok, insert_selected(ctx, side)}

      choice when choice in 2..4 ->
        item = %{2 => 717, 3 => 715, 4 => 716}[choice]
        local = if side == :left, do: :insert, else: :insert2
        {:ok, ctx |> set_local(local, item) |> insert_selected(side)}

      _ ->
        {:cancel, ctx}
    end
  end

  defp insert_selected(ctx, side) do
    local = if side == :left, do: :insert, else: :insert2
    item = get_local(ctx, local, 0)

    cond do
      not Rathena.truthy?(item) ->
        ctx

      count_item(ctx, item) > 0 ->
        ctx =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("^3355FFYou inserted a ", Rathena.getitemname(item)),
              ""
            )
          )
          |> mes("into the eye socket.^000000")
          |> next()
          |> mes("^3355FFThe gemstone rolled back out of")
          |> mes("the mouth of the skull.^000000")

        amount = if side == :left or item == get_local(ctx, :insert, 0), do: 1, else: 2
        ctx = set_local(ctx, :skulldoor, get_local(ctx, :skulldoor, 0) + amount)

        ctx =
          case {side, item} do
            {:left, 715} -> set_local(ctx, :skull, 2)
            {:left, 716} -> set_local(ctx, :skull, 3)
            {:left, 717} -> set_local(ctx, :skull, 1)
            _ -> ctx
          end

        ctx |> delitem(item, 1) |> give_item(item, 1) |> next()

      true ->
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("^3355FFYou forgot to carry ", Rathena.getitemname(item)),
            ""
          )
        )
        |> mes("with you. So you couldn't do what you")
        |> mes("had intended.^000000")
        |> next()
    end
  end

  defp try_door(ctx) do
    ctx =
      ctx
      |> mes("^3355FF..............................^000000")
      |> next()
      |> mes("^3355FF..............................")
      |> mes("..............................^000000")
      |> next()
      |> mes("^3355FF..............................")
      |> mes("..............................")
      |> mes("..............................^000000")
      |> next()

    opens =
      case get_local(ctx, :skulldoor, 0) do
        3 -> Enum.random(1..4) != 1
        2 -> Enum.random(1..2) == 2
        1 -> Enum.random(1..4) == 1
        _ -> false
      end

    ctx = if opens, do: set_local(ctx, :skullopen, 1), else: ctx

    if get_local(ctx, :skullopen, 0) == 0 do
      ctx
      |> mes("^3355FFNothing happened.")
      |> mes("You have the feeling that the")
      |> mes("skull is grinning at you. But...")
      |> mes("It's probably just a trick of the light.^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFSuddenly, a clicking sound comes")
      |> mes("from the skull's eye sockets and")
      |> mes("the door opens. Before you know")
      |> mes("it, you walk inside as if guided")
      |> mes("by an unseen force...^000000")
      |> close2()
      |> warp("um_in", 32, 71)
    end
  end
end
