defmodule Aesir.ZoneServer.Content.Npc.Functions.FClocktowergate do
  @moduledoc """
  Guards a floor of the Aldebaran clock tower.

  ## Behavior

  Greets the player with the floor they are trying to enter and offers four choices: the history of
  the tower, what is known about that floor, passing through when the required key is carried, or
  ending the dialog. Passing through consumes one key and warps to the floor, and every other
  choice ends the conversation where the reference does.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/aldebaran.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Callable rAthena global function `F_ClockTowerGate(floor, item_req, map, x, y)`; returns
  `{ctx, nil}` when the player ends the dialog.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil} | no_return()
  def call(ctx, args) do
    floor = Enum.at(args, 0, 0)

    ctx =
      ctx
      |> mes("[Gatekeeper Boy]")
      |> mes("Welcome to")
      |> mes("Kinase - Blue Gallino")
      |> mes("The one of Local Speciality in Aldebaran.")
      |> mes("You can't go through from #{floor} Floor,")
      |> mes("Please go back.")
      |> next()

    options =
      "About Clock Tower:About the #{floor} Floor:Move to the #{floor} Floor:End Dialogue"
      |> String.split(":")

    {ctx, choice} = select(ctx, options)

    case choice do
      1 -> throw({:script_end, tower_history(ctx)})
      2 -> throw({:script_end, floor_history(ctx)})
      3 -> throw({:script_end, pass_through(ctx, Enum.at(args, 1, 0), args)})
      4 -> throw({:script_end, interior_notice(ctx)})
      _other -> {ctx, nil}
    end
  end

  defp tower_history(ctx) do
    ctx
    |> mes("[Gatekeeper Boy]")
    |> mes("Homeland of Alchemy, Aldebaran!")
    |> mes("Long Time ago, there were")
    |> mes("3 Legendary Alchemists...They are")
    |> mes("Bruke Seimer")
    |> mes("Philip Warisez")
    |> mes("And ..")
    |> next()
    |> mes("[Gatekeeper Boy]")
    |> mes("Romero Specialre!")
    |> mes("This venerable architecture is")
    |> mes("their masterpiece.")
    |> mes("I assume you would feel something unusual")
    |> mes("While on the way to this floor,")
    |> mes("Every feature of This Clocktower ")
    |> next()
    |> mes("[Gatekeeper Boy]")
    |> mes("Consists of Mysterious Ancient Magics.")
    |> mes("If you just wander around here,")
    |> mes(" without any intention")
    |> next()
    |> mes("[Gatekeeper Boy]")
    |> mes("By any means,")
    |> mes("You will meet with a mishap")
    |> mes("by Gatekeeper Creatures.")
    |> mes("Please be careful ..")
    |> close()
  end

  defp floor_history(ctx) do
    ctx
    |> mes("[Gatekeeper Boy]")
    |> mes("Ancient Alchemists")
    |> mes("Sealed the Gate of 4th Floor using an Alchemistic Device ")
    |> mes("To keep something")
    |> mes("From Evil Creatures and Human Enemies.")
    |> mes("To go through this door")
    |> next()
    |> mes("[Gatekeeper Boy]")
    |> mes("It needs a Key.")
    |> mes("That Key has rumored to be possessed by Gatekeeper Creatures")
    |> mes("Prowling around here.")
    |> next()
    |> mes("[Gatekeeper Boy]")
    |> mes("The Key is the Intensiveness of Ancient Alchemy,")
    |> mes("By hearsay When used once,")
    |> mes("It will be released from being spelled")
    |> mes("And be disappeared.")
    |> next()
    |> mes("[Gatekeeper Boy]")
    |> mes("If that key")
    |> mes("Comes into your possession,")
    |> mes("Please show me.")
    |> mes("The one who possesses the Key")
    |> mes("Will have access to go through")
    |> mes("This Gate with his own will!")
    |> next()
    |> mes("[Gatekeeper Boy]")
    |> mes("I will give you a chance.")
    |> mes(". . . . .")
    |> close()
  end

  defp pass_through(ctx, key, args) do
    if count_item(ctx, key) > 0 do
      ctx
      |> mes("[Gatekeeper Boy]")
      |> mes("Hmm! I already felt that you are not an Ordinary person,")
      |> mes("Now it seems to be successful in Speculation.")
      |> mes("Please, you may enter.")
      |> mes("May God bless you ..")
      |> close()
      |> delitem(key, 1)
      |> warp(Enum.at(args, 2, 0), Enum.at(args, 3, 0), Enum.at(args, 4, 0))
    else
      ctx
      |> mes("[Gatekeeper Boy]")
      |> mes(". . . . . .")
      |> mes("Unfortunately you don't have a privilege")
      |> mes("To enter this Gate ..")
      |> mes("You won't be able to go through")
      |> mes("As long as Ancient Alchemists")
      |> mes(" Don't grant you.")
      |> close()
    end
  end

  defp interior_notice(ctx) do
    ctx
    |> mes("[Gatekeeper Boy]")
    |> mes("This Clock Tower")
    |> mes("Is the place where the 3 Ancient Legendary Alchemists")
    |> mes("Has left their Spirits and Skills.")
    |> mes("Please Do not Scribble or Damage on the Interior.")
    |> close()
  end
end
