defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesUmbala.Adventurer do
  @moduledoc """
  Adventurer who helps visitors find Umbala's village landmarks.

  ## Behavior

  - Describes buildings and the bungee jump site and marks them on the mini-map.
  - Removes all location marks on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dizzy
    - Celest
    - L0ne_W0lf
    - Lupus
    - erKURITA

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "umbala",
        x: 128,
        y: 94,
        dir: 4,
        sprite: 702,
        name: "Adventurer",
        scope: :pre_renewal,
        unique_name: "Adventurer#um"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Adventurer]")
      |> mes("This is a very strange place...")
      |> mes("It's underdeveloped, and there")
      |> mes("are a number of complex, winding paths...")
      |> next()
      |> mes("[Adventurer]")
      |> mes("However, since I have been here")
      |> mes("for months, I am familiar with")
      |> mes("this area's geography and points")
      |> mes("of interest in this village.")
      |> mes("You're welcome to ask me about the")
      |> mes("locations of buildings.")
      |> next()
      |> select(["Locations of buildings.", "Remove marks on the mini map.", "Quit."])

    ctx =
      case choice do
        1 ->
          choose_location(ctx)

        2 ->
          remove_marks(ctx)

        3 ->
          ctx
          |> mes("[Adventurer]")
          |> mes("It's fun to learn Utan culture on your own. Take care.")

        _ ->
          ctx
      end

    close(ctx)
  end

  defp choose_location(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Adventurer]")
      |> mes("So, which one do you want to check?")
      |> next()
      |> select([
        "Chief's House",
        "Shaman's House",
        "Weapon Shop",
        "Tool Shop",
        "Bungee Jump Place",
        "Cancel"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Adventurer]")
        |> mes("I have made a ^FF3355+^000000 mark")
        |> mes("on your mini map.")
        |> next()
        |> mes("[Adventurer]")
        |> mes("Only the chief knows the language")
        |> mes("of the outside world. So you'd")
        |> mes("better visit him before anything else.")
        |> viewpoint(1, 66, 250, 2, 0xFF3355)

      2 ->
        ctx
        |> mes("[Adventurer]")
        |> mes("I have made a ^CE6300+^000000 mark")
        |> mes("on your mini map.")
        |> next()
        |> mes("[Adventurer]")
        |> mes("The Utan Shaman has some")
        |> mes("sort of mystic power...")
        |> mes("People say she can create rough")
        |> mes("enchanted stones, and divide a")
        |> mes("pure enchanted stone into rough ones.")
        |> viewpoint(1, 217, 186, 3, 0xCE6300)

      3 ->
        ctx
        |> mes("[Adventurer]")
        |> mes("I have made a ^55FF33+^000000 mark")
        |> mes("on your mini map.")
        |> next()
        |> mes("[Adventurer]")
        |> mes("The Utans are usually well armed")
        |> mes("in preparation for attacks from")
        |> mes("their enemies. Apparently, they")
        |> mes("have been attacked from the outside many times in the past.")
        |> viewpoint(1, 126, 154, 4, 0x55FF33)

      4 ->
        ctx
        |> mes("[Adventurer]")
        |> mes("I have made a ^3355FF+^000000 mark")
        |> mes("on your mini map.")
        |> next()
        |> mes("[Adventurer]")
        |> mes("There are many useful things for")
        |> mes("traveling in the Tool Shop, so why don't you go look around?")
        |> viewpoint(1, 136, 127, 5, 0x3355FF)

      5 ->
        ctx
        |> mes("[Adventurer]")
        |> mes("I have made a ^00FF00+^000000 mark")
        |> mes("on your mini map.")
        |> next()
        |> mes("[Adventurer]")
        |> mes("Umbala has a unique locale called")
        |> mes("the 'Bungee Jump Place'.")
        |> mes("If you're interested in testing")
        |> mes("your courage, why don't you go")
        |> mes("and partake in this Utan")
        |> mes("ritual yourself?")
        |> viewpoint(1, 139, 198, 6, 0x00FF00)

      6 ->
        ctx
        |> mes("[Adventurer]")
        |> mes("If you want to remove the location")
        |> mes("marks on your mini map, please")
        |> mes("choose 'Remove marks on the mini map' menu.")

      _ ->
        ctx
    end
  end

  defp remove_marks(ctx) do
    ctx
    |> viewpoint(2, 66, 250, 2, 0xFF3355)
    |> viewpoint(2, 217, 186, 3, 0xCE6300)
    |> viewpoint(2, 126, 154, 4, 0x55FF33)
    |> viewpoint(2, 136, 127, 5, 0x3355FF)
    |> viewpoint(2, 139, 198, 6, 0x00FF00)
    |> mes("[Adventurer]")
    |> mes("I removed all the marks from your")
    |> mes("mini map. Feel free to ask me")
    |> mes("again if you want me to mark building locations.")
  end
end
