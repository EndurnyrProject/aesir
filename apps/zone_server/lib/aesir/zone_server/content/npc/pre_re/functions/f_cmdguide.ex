defmodule Aesir.ZoneServer.Content.Npc.PreRe.Functions.FCmdguide do
  @moduledoc """
  Comodo guide dialogue shared by every Comodo guide, each speaking under its own name.

  ## Behavior

  - Welcomes the visitor and, for the chosen facility, marks it on the mini-map with a short
    description.
  - Ending the conversation explains why Comodo always looks like nighttime.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - MasterOfMuppets

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"Casino", {140, 98, 0, 0xFF6633},
     ["Casino, a haven for rest for", "weary travlers and the heart", "of Comodo's nightlife."]},
    {"Hula Dance Stage ^3355FF(Dancer Job Change)^000000", {188, 168, 1, 0x0000FF},
     ["Hula Dance Stage, the place", "where female Archers can", "change jobs to Dancers."]},
    {"Weapon and Armor Shop", {266, 70, 2, 0x00FFFF},
     [
       "Weapon and Armor shop. Be",
       "sure to check that shop for",
       "any special items that are",
       "unique to Comodo!"
     ]},
    {"Tool Shop", {86, 128, 3, 0x515151},
     [
       "Tool Shop. If you've never been",
       "there before, then I suggest",
       "you check it out and stock up",
       "on tools you might need later."
     ]},
    {"Tourist Shop", {298, 124, 4, 0x3355FF},
     [
       "Tourist Shop where you can ",
       "buy gifts that can only be found in the Comodo region~"
     ]},
    {"Kafra Co. Western Branch", {136, 202, 5, 0xFF5555},
     [
       "Western branch of the Kafra",
       "Corporation. They offer some",
       "pretty important services that you may want to check out later."
     ]},
    {"Chief's House", {114, 294, 5, 0xFF5555},
     [
       "Chief's House. You're welcome",
       "to visit him, and he's usually",
       "happy to have visitors."
     ]},
    {"Pub", {166, 298, 5, 0xFF5555},
     [
       "Pub. There, you can meet other",
       "tourists, relax, and socialize",
       "in an enjoyable environment~"
     ]},
    {"Campground", {210, 308, 5, 0xFF5555},
     [
       "Campground. Gather with your",
       "family and friends, and enjoy",
       "the special barbeque of",
       "Comodo's camping grounds~"
     ]}
  ]

  @location_count length(@locations)
  @location_menu Enum.map(@locations, &elem(&1, 0)) ++ ["End Conversation"]

  @doc """
  Runs the guide dialogue with `speaker` as the name shown in the dialogue header.

  Keeps the rAthena global function shape: arguments as a list and a `{ctx, nil}` return.
  """
  @spec call(Ctx.t(), [String.t()]) :: {Ctx.t(), nil}
  def call(ctx, [speaker]) do
    {ctx, choice} =
      ctx
      |> mes("[#{speaker}]")
      |> mes("Welcome to Comodo, the")
      |> mes("city of dreams and fantasy,")
      |> mes("where the nightlife never ends!")
      |> mes("I know this area really well,")
      |> mes("so let me know if you need")
      |> mes("directions anywhere here.")
      |> next()
      |> select(@location_menu)

    ctx =
      case choice do
        choice when choice in 1..@location_count ->
          ctx |> point_to(Enum.at(@locations, choice - 1)) |> close()

        choice when choice == @location_count + 1 ->
          ctx
          |> mes("[#{speaker}]")
          |> mes("Actually, it always looks")
          |> mes("like nighttime in Comodo")
          |> mes("because it's built in a huge")
          |> mes("cave. We don't get any sunlight")
          |> mes("here, but the darkness here is")
          |> mes("more exciting than gloomy~")
          |> close()

        _ ->
          ctx
      end

    {ctx, nil}
  end

  defp point_to(ctx, {_label, {x, y, id, color}, lines}) do
    marker = color |> Integer.to_string(16) |> String.pad_leading(6, "0")

    ctx =
      ctx
      |> viewpoint(1, x, y, id, color)
      |> mes("Please refer to the cross mark,")
      |> mes("^#{marker}+^000000, on your Mini-Map to find the")

    Enum.reduce(lines, ctx, &mes(&2, &1))
  end
end
