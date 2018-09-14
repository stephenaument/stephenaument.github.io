---
layout: post
title: "Null Object Part 2"
date: 2014-03-06 19:21:15 -0600
date: 2014-03-11 00:00:00 -0600
comments: true
categories: Design Patterns
tags: code
image:
  credit: Photo by Ann H on Pexels
  feature: /assets/images/hero/bath-duck-close-up-cute-592677.jpg
  topPosition: -420px
bgContrast: dark
bgGradientOpacity: lighter
syntaxHighlighter: no
author:
  name: Step Aument
---

In a [previous post](/blog/2014/03/05/the-null-object-pattern-and-method-missing-in-ruby/) I
described using {% ihighlight ruby %}method_missing{% endihighlight %} in a Null Object to stand in for another
object and respond smartly to the original object's interface. At the end of
that post I suggested that you could go farther than we did in creating a more
abstract object. Well, we got that chance.

In this post I will show you how we created a {% ihighlight ruby %}NilObject{% endihighlight %} that can both stand
on its own and be extended with added functionality in a subclass. Our
{% ihighlight ruby %}NilObject{% endihighlight %} needs to be smart about the interface of the class that it's
faking, so we'll have to take that into account. Finally, we decided to
implement a smart {% ihighlight ruby %}respond_to?{% endihighlight %} method to round out the functionality of our
{% ihighlight ruby %}NilObject{% endihighlight %}.

Here's the form that our {% ihighlight ruby %}NilDuck{% endihighlight %} took at the end of the previous post:

{% highlight ruby linedivs %}
class NilDuck
  def name
    'Demo Duck'
  end

  def status
    'sleeping'
  end

  def color
    'gray'
  end

  def migratory?
    true
  end

  def method_missing(name, *args)
    super unless Duck.new.respond_to?(name)
    name.ends_with?('?') ? false : nil
  end
end
{% endhighlight %}

A few days after making those changes, we ran into another custom Null Object
in our app, the {% ihighlight ruby %}NilGoose{% endihighlight %}. Our {% ihighlight ruby %}NilGoose{% endihighlight %} ran into the
same problem that {% ihighlight ruby %}NilDuck{% endihighlight %} originally did. A new method was added to the
{% ihighlight ruby %}Goose{% endihighlight %} class that wasn't reflected in {% ihighlight ruby %}NilGoose{% endihighlight %} and a bug appeared.

What to do? Well, we try not to run ahead of ourselves or our tests, so the
first thing we did was create a test that expected the missing method, watched
it fail, and copied the {% ihighlight ruby %}method_missing{% endihighlight %} definition from {% ihighlight ruby %}NilDuck{% endihighlight %}, renaming as
we needed to.

{% highlight ruby linedivs %}
class NilGoose
  def name
    'Demo Goose'
  end
 
  def status
    'awake'
  end
 
  def color
    'black'
  end
 
  def migratory?
    true
  end
 
  def method_missing(name, *args)
    super unless Goose.new.respond_to?(name)
    name.ends_with?('?') ? false : nil  end
end
{% endhighlight %}

This made our test happy. But the duplicated code made us sad. We like
[DRY](http://en.wikipedia.org/wiki/Don't_repeat_yourself) code around here. We
knew it was time to factor out our common code into a single spot.

We thought about putting it in a Module that could be included into other
special null objects, but decided instead to make it a full-fledged {% ihighlight ruby %}NilObject{% endihighlight %}
class that we could use standalone as well as a superclass for our {% ihighlight ruby %}NilDuck{% endihighlight %}
and {% ihighlight ruby %}NilGoose{% endihighlight %}.

{% highlight ruby linedivs %}
class NilObject
  def initialize(klass)
    @klass = klass
  end

  def method_missing(name, *args)
    return super unless @klass.new.respond_to?(name)
    name.to_s.ends_with?('?') ? false : nil
  end
end
{% endhighlight %}

If you recall in our {% ihighlight ruby %}method_missing{% endihighlight %} implementation, we had to new up an
instance of our {% ihighlight ruby %}Duck{% endihighlight %} class to determine whether it responds to the method we
are testing. Since we want to reuse this method in the generic {% ihighlight ruby %}NilObject{% endihighlight %}, we
won't know which class to check. Our first pass at a solution requires the
class to be passed into the {% ihighlight ruby %}NilObject{% endihighlight %} constructor, which would look like
{% ihighlight ruby %}faker = NilObject.new(Duck){% endihighlight %}.

In our {% ihighlight ruby %}initialize{% endihighlight %} method we save the class passed in into an instance
variable, {% ihighlight ruby %}@klass{% endihighlight %}, which {% ihighlight ruby %}method_missing{% endihighlight %} then uses to new up an instance to
check. Now we can fake any class we want with our {% ihighlight ruby %}NilObject{% endihighlight %}, and it will
handle exactly those methods the subject responds to and no others. (Note: If
you're weirded out by passing a class around like that, remember that
everything in Ruby is an object, including classes)

Now we can make {% ihighlight ruby %}NilDuck{% endihighlight %} inherit from {% ihighlight ruby %}NilObject{% endihighlight %}:

{% highlight ruby linedivs %}
class NilDuck < NilObject
  def name
    'Demo Duck'
  end

  def status
    'sleeping'
  end

  def color
    'gray'
  end

  def migratory?
    true
  end
end
{% endhighlight %}

and the same for `NilGoose`:

{% highlight ruby linedivs %}
class NilGoose < NilObject
  def name
    'Demo Goose'
  end
 
  def status
    'awake'
  end
 
  def color
    'black'
  end
 
  def migratory?
    true
  end
end
{% endhighlight %}

This is all very cool, but if I leave the code like this I'm going to have to
run around and find every place in the app in which I create an instance of
`NilDuck` or `NilGoose` and add the new argument. Hopefully it's not very many
places, but this is not something I want to do. Let's go ahead and add
initialize methods to our `NilDuck` and `NilGoose` classes to take care of
that:

{% highlight ruby linedivs %}
class NilDuck < NilObject
  def initialize
    super(Duck)
  end

  def name
    'Demo Duck'
  end
 
  def status
    'sleeping'
  end
 
  def color
    'gray'
  end
 
  def migratory?
    true
  end
end
{% endhighlight %}

and

{% highlight ruby linedivs %}
class NilGoose < NilObject
  def initialize
    super(Goose)
  end

  def name
    'Demo Goose'
  end
 
  def status
    'awake'
  end
 
  def color
    'black'
  end
 
  def migratory?
    true
  end
end
{% endhighlight %}

That works, and it keeps us from having to spread changes around the codebase,
but it does add to the duplication a bit. That initialize method needs to be
added to every new subclass in order to get the shorter `NilSomething.new`
syntax. We could live with this, or we could find a way to bake that smarts
into `NilObject` itself. But how?

My pair for the week, [@timtyrell](https://twitter.com/timtyrrell) came up with
the idea of keying off of the classname of the `NilObject` subclass. And that's
exactly what we did, we made the class parameter optional and keyed off of the
classname.

{% highlight ruby linedivs %}
class NilObject
  def initialize(klass=nil)
    @klass = klass || real_class_name
  end

  def method_missing(name, *args)
    return super unless @klass.new.respond_to?(name)
    name.to_s.ends_with?('?') ? false : nil
  end

  def real_class_name
    self.class.name[3..-1].constantize
  end
end
{% endhighlight %}

The `real_class_name` method (naming is hard; this should probably be
`subject_class_name` or something) takes the name of the class, `NilDuck` or
`NilGoose` and takes the substring that skips the first 3 letters (the length
of 'Nil') to the end. It then turns it into a constant so it can be
instantiated.

As an added bonus we decided to implement `respond_to?` so it behaves exactly
like the subject class would behave.

{% highlight ruby linedivs %}
class NilObject
  def initialize(klass=nil)
    @klass = klass || real_class_name
  end

  def method_missing(name, *args)
    return super unless respond_to?(name)
    name.to_s.ends_with?('?') ? false : nil
  end

  def respond_to?(name)
    @klass.new.respond_to?(name)
  end

  def real_class_name
    self.class.name[3..-1].constantize
  end
end
{% endhighlight %}

So there you have it. We now have a `NilObject` that can stand in for any other
object like so: `NilObject.new(MyOtherClass)` and it will respond to exactly
the same interface as `MyOtherClass` and answer `respond_to?` just like an
instance of `MyOtherClass` would. If we need to override some of the methods of
`MyOtherClass` to return other than `nil` or `false` we can create a new
`NilMyOtherClass` as a subclass of `NilObject` and override what we need to.

I'll leave you with a thought exercise. What would happen if you instantiated a
`NilObject` without passing a class to the constructor: `nil_object =
NilObject.new`? What would you get? As a bonus, how would you make the code
inside the `real_class_name` method more intention revealing than what we wrote?
Leave a comment if you know the answers.
