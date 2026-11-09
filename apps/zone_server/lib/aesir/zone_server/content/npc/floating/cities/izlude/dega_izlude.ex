defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Izlude.DegaIzlude do
  @moduledoc """
  Dega, an Izlude resident who talks about Mt. Mjolnir, desert Golems or Porings.

  ## Behavior

  - Picks one of three topics per interaction: the climb past Mt. Mjolnir, the
    Golem that senses magic, or the Poring family near the bridge to Payon.
  - The Poring topic opens a question menu about Ghostring and Angeling that
    the player can ask about repeatedly until they choose to end the
    conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Nexon
    - Silentdragon
    - MasterOfMuppets
    - Silent
    - Evera
    - CAHTEXHuK
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/izlude.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 85,
        y: 103,
        dir: 4,
        sprite: 84,
        name: "Dega",
        scope: :renewal,
        unique_name: "Dega#izlude"
      },
      %{
        map: "izlude_a",
        x: 85,
        y: 103,
        dir: 4,
        sprite: 84,
        name: "Dega",
        scope: :renewal,
        unique_name: "Dega#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 85,
        y: 103,
        dir: 4,
        sprite: 84,
        name: "Dega",
        scope: :renewal,
        unique_name: "Dega#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 85,
        y: 103,
        dir: 4,
        sprite: 84,
        name: "Dega",
        scope: :renewal,
        unique_name: "Dega#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 85,
        y: 103,
        dir: 4,
        sprite: 84,
        name: "Dega",
        scope: :renewal,
        unique_name: "Dega#izlude_d"
      },
      %{
        map: "izlude",
        x: 150,
        y: 118,
        dir: 2,
        sprite: 84,
        name: "Dega",
        scope: :pre_renewal,
        unique_name: "Dega#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Dega]")

    case :rand.uniform(3) - 1 do
      1 -> about_mt_mjolnir(ctx)
      2 -> about_golems(ctx)
      _ -> about_porings(ctx)
    end
  end

  defp about_mt_mjolnir(ctx) do
    ctx
    |> mes("Mt. Mjornir, located north of Prontera, is a tough")
    |> mes("and steep climb.")
    |> next()
    |> mes("[Dega]")
    |> mes(
      "Aside from the dangers of the mountain itself, insanely vicious insects live there too. I mean, they'll just attack you for no reason."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "If you ever want to visit somewhere past Mt. Mjolnir, then you prepare yourself for the challenge.  Or you could walk around it."
    )
    |> close()
  end

  defp about_golems(ctx) do
    ctx
    |> mes(
      "Some monsters in the world have the unique ability to sense mystical energy, and can detect Magic spells before they are cast."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "Golem of the desert is one of them. Don't underestimate it due to its sluggishness..."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "If you try to cast magic near it, it will notice and saunter over to smash you. So you better watch out for Golem."
    )
    |> close()
  end

  defp about_porings(ctx) do
    ctx
    |> mes("There's a very delightful place where you can find every")
    |> mes("type of Poring.")
    |> next()
    |> mes("[Dega]")
    |> mes(
      "It's somewhere near the bridge connecting the forest and the desert, on the way to the city of Payon which is Southeast from here."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "There are not only pink Porings but also Drops, which can be found at the desert, and the green Poporing."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "But be careful, before you realize it, you may come face to face with Ghostring, a deadly Poring that floats around in the air like a ghost."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "Well, of course, they are all very cute, but Ghostring is an EXCEPTION. It is very very dangerous."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "If you are lucky enough, you might even bump into Angeling, the Poring with Angel wings."
    )
    |> next()
    |> poring_questions()
  end

  defp poring_questions(ctx) do
    {ctx, question} = select(ctx, ["Ghostring?", "Angeling?", "End Conversation."])

    case question do
      1 -> ctx |> ghostring_answer() |> poring_questions()
      2 -> ctx |> angeling_answer() |> poring_questions()
      3 -> ctx |> mes("[Dega]") |> mes("Good Luck~") |> close()
      _ -> poring_questions(ctx)
    end
  end

  defp ghostring_answer(ctx) do
    ctx
    |> mes("[Dega]")
    |> mes(
      "Ghostring is a grayish Poring that floats around in the air like a ghost. Just like other ghosts, physical attacks can't do any damage to it."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "Those whose main attack methods are physical like Swordman and Archer might have to run for their lives when facing Ghostrings."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "But don't leave just yet~! There is great news for people with those jobs. Making a weapon of some elemental property is the key."
    )
    |> next()
    |> mes("[Dega]")
    |> mes(
      "This way, even a Swordman or an Archer can inflict damage, the way Magic does, on Ghostrings."
    )
    |> next()
  end

  defp angeling_answer(ctx) do
    ctx
    |> mes("[Dega]")
    |> mes(
      "Angelings are immune to Magic attacks. If people who can only attack with Magic face an Angeling, then it's time for"
    )
    |> mes("them to run.")
    |> next()
    |> mes("[Dega]")
    |> mes(
      "If you've got an extra knife or sword, you could give it a shot. But it will be very difficult alone, don't you think?"
    )
    |> next()
  end
end
