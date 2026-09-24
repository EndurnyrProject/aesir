defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesMoscovia.MoscoviaGuide do
  @moduledoc """
  Moscovia guide who introduces the town and marks its facilities on the mini-map.

  ## Behavior

  - Describes the palace, shops, and inn, marking each location on the mini-map.
  - Removes all location marks on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "moscovia",
        x: 161,
        y: 76,
        dir: 4,
        sprite: 959,
        name: "Moscovia Guide",
        scope: :pre_renewal,
        unique_name: "Moscovia Guide#mosk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moscovia Guide]")
      |> mes("Welcome to Moscovia")
      |> mes("Here is the paradise spreading on")
      |> mes("the endless seas")
      |> mes("You'll be happy with the beautiful")
      |> mes("scenery and the sunlight!")
      |> next()
      |> mes("[Moscovia Guide]")
      |> mes("I was sent from Moscovia Palace")
      |> mes("to guide tourists and to give them")
      |> mes("information on this town.")
      |> mes("If you have some questions, please ask me.")
      |> next()
      |> select(["Ask where you can go.", "Delete all the marks on the mini-map.", "Cancel."])

    case choice do
      1 ->
        choose_location(ctx)

      2 ->
        remove_marks(ctx)

      3 ->
        ctx
        |> mes("[Moscovia Guide]")
        |> mes("It'd be great to walk about alone.")
        |> mes("Take care.")
        |> close()

      _ ->
        ctx
    end
  end

  defp choose_location(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moscovia Guide]")
      |> mes("Where would you like to go?")
      |> next()
      |> select(["The Palace", "Armor Shop", "Tool Shop", "An Inn", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes("[Moscovia Guide]")
        |> mes("The Palace can be found ^ff0000+^000000 at the")
        |> mes("end of the North sea from")
        |> mes("Rune-Midgarts.")
        |> mes("There resides our Lord the Czar of")
        |> mes("Moscovia and his retainers.")
        |> close()
        |> viewpoint(1, 257, 138, 1, 0xFF0000)

      2 ->
        ctx
        |> viewpoint(1, 185, 187, 2, 0x00FF00)
        |> mes("[Moscovia Guide]")
        |> mes("The Armor Shop is located at the")
        |> mes("southwest corner of town..")
        |> mes("You can buy armor made by the best")
        |> mes("craftsmen of Moscovia there.")
        |> close()

      3 ->
        ctx
        |> mes("[Moscovia Guide]")
        |> mes("The Tool Shop is located just south")
        |> mes("from the center of town.")
        |> mes("You can find all sorts of things")
        |> mes("you need for your travels.")
        |> close()
        |> viewpoint(1, 223, 174, 3, 0x00FF00)

      4 ->
        ctx
        |> mes("[Moscovia Guide]")
        |> mes("The Inn 'Sticky Herb Tree' is just")
        |> mes("north from the center of town.")
        |> mes("If you need to rest, there is no")
        |> mes("better place to stay.")
        |> close()
        |> viewpoint(1, 229, 208, 4, 0x3355FF)

      5 ->
        close(ctx)

      _ ->
        remove_marks(ctx)
    end
  end

  defp remove_marks(ctx) do
    ctx
    |> mes("[Moscovia Guide]")
    |> mes("I've deleted all marks on the mini-map.")
    |> mes("Whenever you'd like to put marks")
    |> mes("there, you can ask me.")
    |> viewpoint(2, 257, 138, 1, 0xFF0000)
    |> viewpoint(2, 185, 187, 2, 0x00FF00)
    |> viewpoint(2, 223, 174, 3, 0x00FF00)
    |> viewpoint(2, 229, 208, 4, 0x3355FF)
    |> close()
  end
end
