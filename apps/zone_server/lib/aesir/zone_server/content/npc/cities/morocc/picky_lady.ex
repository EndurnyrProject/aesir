defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.PickyLady do
  @moduledoc """
  Discusses Angeling and Ghostring while mourning Morocc’s changed wildlife.

  ## Behavior

  - Offers information about Angeling or Ghostring.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 121,
        y: 116,
        dir: 4,
        sprite: 66,
        name: "Picky Lady",
        scope: :shared,
        unique_name: "Picky Lady#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Syvia]")
      |> mes(
        "The fields of Rune-Midgarts are infested with wild and dangerous monsters..But, you've got to admit a bunch of them are soooo cute!"
      )
      |> mes("You know, like how Spore sticks out its tongue after you kill it..")
      |> next()
      |> mes("[Syvia]")
      |> mes("Or, how little Picky wears that tiny egg shell sometimes?..")
      |> next()
      |> mes("[Syvia]")
      |> mes(
        "I can't believe what just has happened.. Our town used to be the one with those cute little monsters, not that kinda of vicious dreadful Evil sleeping in! Whew..."
      )
      |> next()
      |> mes("[Syvia]")
      |> mes(
        "I'm so scared... I just wanna ease my mind watching over those cute little Porings..."
      )
      |> next()
      |> select(["What about Angeling?", "How about Ghostring?", "Quit Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Syvia]")
        |> mes(
          "Ooh! Angeling is just like Poring, except it has angel wings! Of course, I don't know if they can actually fly.."
        )
        |> next()
        |> mes("[Syvia]")
        |> mes(
          "Angelings are rarely seen, but can be found among large groups of Porings living in one of the fields south of Prontera."
        )
        |> mes(
          "Angeling is a high level monster with Holy property, so it's immune to most magic, aside from spells that have Neutral or Shadow attack properties."
        )
        |> next()
        |> mes("[Syvia]")
        |> mes("Hehe~ Don't you think I know a lot about Porings? I love them soooo much")
        |> next()
        |> mes("[Syvia]")
        |> mes("Hehe... Poring... Hee......")
        |> close()

      2 ->
        ctx
        |> mes("[Syvia]")
        |> mes(
          "Ghostring is an evil ghost Poring. It's rarely seen, but can be found among mass groups of Porings living in one of the fields south of Prontera."
        )
        |> next()
        |> mes("[Syvia]")
        |> mes(
          "Ghostring is a high-leveled monster with the Ghost property, so it can withstand all physical attacks."
        )
        |> mes(
          "Damage can only be caused to Ghostring through magic spells or weapons with an a specific property."
        )
        |> next()
        |> mes("[Syvia]")
        |> mes("Hehe~ Don't you think I know a lot about Porings? I love them soooo much~")
        |> next()
        |> mes("[Syvia]")
        |> mes("Hehe... Poring... Teehee......")
        |> close()

      3 ->
        ctx |> mes("[Syvia]") |> mes("Hehe... Poring... Teehee......") |> close()

      _ ->
        ctx
    end
  end
end
