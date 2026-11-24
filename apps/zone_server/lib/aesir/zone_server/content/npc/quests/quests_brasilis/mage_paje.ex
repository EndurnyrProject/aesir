defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.MagePaje do
  @moduledoc """
  Mage Paje disguises adventurers as animals during the Guarana Candy quest.

  ## Behavior

  - Changes Poring’s appearance and gives quest participants an animal disguise.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 56,
        y: 224,
        dir: 7,
        sprite: 704,
        name: "Mage Paje",
        scope: :shared,
        unique_name: "Mage Paje#bra"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Mage Paje]")
      |> mes("Abracadabra~")
      |> specialeffect(:poisonhit, :area, "Poring#bra")
      |> set_local(:display, [800, 876, 909])

    ctx =
      set_npc_display(ctx,
        npc: "Poring#bra",
        sprite: Enum.at(get_local(ctx, :display, []), :rand.uniform(3) - 1, 0)
      )

    if get_char_var(ctx, :brazil_gua, 0) == 5 do
      teach_magic(ctx)
    else
      close(ctx)
    end
  end

  defp teach_magic(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Mage Paje]")
      |> mes("Ohoooh~!")
      |> mes("I have a guest.")
      |> mes("Good to see you.")
      |> mes("I am the Mage Paje.")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hello. Mr. Cherto told me to find you.")
      |> next()
      |> mes("[Mage Paje]")
      |> mes("Um.. Mr. Cherto? What's happened?")
      |> mes("Have you come here to ask about lots of weird rumors?")
      |> next()
      |> mes("- You give the note to Paje-")
      |> next()
      |> mes("[Mage Paje]")
      |> mes("Ohoooh~")
      |> mes("Hmm gosh.. that's what happened.")
      |> next()
      |> mes("[Mage Paje]")
      |> mes("I can't help you directly.")
      |> mes("But I will give you simple magic so you can figure it out by yourself.")
      |> next()
      |> select(["What kind of magic?"])

    ctx
    |> mes("[Mage Paje]")
    |> mes(
      "It's a magic that will make you appear as an animal to other animals. Pretty cool huh?"
    )
    |> next()
    |> mes("[Mage Paje]")
    |> mes("Ok~ I will give you the magic.")
    |> mes(
      "Most animals are really sensitive so they might be aware of it. Find a Toucan in the field that's oblivious to the spell. You'll know when you talk to it."
    )
    |> next()
    |> mes("[Mage Paje]")
    |> mes("Good luck~!")
    |> set_char_var(:brazil_gua, 6)
    |> changequest(2195, 2196)
    |> specialeffect2(:assumptio)
    |> close()
  end
end
