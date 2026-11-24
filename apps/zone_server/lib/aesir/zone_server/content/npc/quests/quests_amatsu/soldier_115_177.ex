defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier115177 do
  @moduledoc """
  Guards the entrance to the palace dungeon.

  ## Behavior

  - Admits eligible permit holders and offers instructions.
  - Confiscates a permit shown before the required quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_in02",
        x: 115,
        y: 177,
        dir: 7,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama10"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jyuro]")
      |> mes("What are you doing in here?")
      |> mes("There is nothing interesting here.")
      |> next()
      |> select(["That is true", "Open the gate"])

    if choice == 1 do
      ctx
      |> mes("[Jyuro]")
      |> mes("There are much better things to enjoy in town. Have a good time...")
      |> close()
    else
      gate(ctx)
    end
  end

  defp gate(ctx) do
    cond do
      get_char_var(ctx, :event_amatsu, 0) != 6 ->
        deny_gate(ctx)

      count_item(ctx, 7160) > 0 ->
        admit(ctx)

      true ->
        ctx
        |> mes("[Jyuro]")
        |> mes("I'm sorry.")
        |> mes("You need a Transit Permit to go in.")
        |> mes("Please, go back.")
        |> close()
    end
  end

  defp admit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jyuro]")
      |> mes("You have the ticket...")
      |> mes("Do you want me to send you now, or do you need a little instruction?")
      |> next()
      |> select(["I will go in", "Instruction, please"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("[Jyuro]")
        |> mes("I will open the gate.")
        |> mes("Take care of yourself...")
      else
        ctx
        |> mes("[Jyuro]")
        |> mes("The area beyond this gate is")
        |> mes("protected by some kind of magic.")
        |> mes("You may get killed by someone")
        |> mes("or get lost.")
        |> mes(" ")
        |> next()
        |> mes("[Jyuro]")
        |> mes("I can't tell you much.")
        |> mes("I didn't go far inside and")
        |> mes("and just took a quick look.")
        |> mes(" ")
        |> mes(" ")
        |> next()
        |> mes("[Jyuro]")
        |> mes("First.....")
        |> mes("'Do not trust what you are")
        |> mes("seeing.' I don't know what")
        |> mes("it means, but I guess you shouldn't believe everything before your eyes.")
        |> next()
        |> mes("[Jyuro]")
        |> mes("Second.....")
        |> mes("'There are certain rules in")
        |> mes("magic.' Everything has a")
        |> mes("reason to exist. Magic is not an exception. You can probably find the answer...")
        |> next()
        |> mes("[Jyuro]")
        |> mes("Well, I will open this gate.")
        |> mes("Take care of yourself...")
      end

    ctx |> close() |> warp("ama_dun01", 229, 10)
  end

  defp deny_gate(ctx) do
    ctx =
      ctx
      |> mes("[Jyuro]")
      |> mes("What gate are you talking about?")
      |> mes("A gate? On the top floor of the building??? Surely, you must been be mistaken.")
      |> emotion(:sweat)
      |> next()

    if count_item(ctx, 7160) > 0 do
      {ctx, choice} = select(ctx, ["Show him the ticket", "Cancel"])

      if choice == 1 do
        ctx
        |> mes("[Jyuro]")
        |> mes("What? That pass is...?")
        |> mes("That Transit Permit is from")
        |> mes("the lord but I guess it has")
        |> mes("been issued to the wrong person.")
        |> next()
        |> delitem(7160, 1)
        |> mes("[Jyuro]")
        |> mes("I will keep this ticket because")
        |> mes("it was issued without permission.")
        |> mes("This is a warning.")
        |> mes("Be careful.")
        |> close()
      else
        ctx
        |> mes("[Jyuro]")
        |> mes("There are more things to enjoy in town. Have a good time...")
        |> close()
      end
    else
      ctx
      |> mes("[Jyuro]")
      |> mes("There are more things to enjoy in town. Have yourself a good time...")
      |> close()
    end
  end
end
