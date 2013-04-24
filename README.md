## NPRImageView

Instagram-like UIImageView subclass. Progress view and activity view appear during image download. Support memory and disk caching. Inspired by [FXImageView](https://github.com/nicklockwood/FXImageView) and [Tapku](https://github.com/devinross/tapkulibrary)'s TKImageCache. Using AFNetworking.

## Features

1. Memory and disk caching
2. Customizable progress view and activity view. Simply set your custom progress view and activity view.
3. Tap image view to reload.
4. Show network activity while downloading images.
5. ARC.
6. Very simple to use. Just one line of code. Or more.

## Screenshots

![Instagram like UIImageView](http://f.cl.ly/items/3X2Z2E020i243l3T3N3H/2013-04-24%20at%2012%3A03.png)

![Instagram like UIImageView](http://f.cl.ly/items/0Q2J2v1D3O072W0a1825/2013-04-24%20at%2012%3A02.png)


## Requirement

1. [AFNetworking](https://github.com/AFNetworking/AFNetworking)
2. [libextobjc](https://github.com/jspahrsummers/libextobjc)

## After clone

    git submodule update --init --recursive

## How to use

1. Import files inside Class folder to your project.
2. Add AFNetworking to your project.
3. Add EXTScope.h, EXTScope.m, and metamacros.h from libextobjc to your project.
4. Simply call `setImageWithContentsOfURL:placeholderImage:` method.

## License
NPRImageView is available under the MIT license, because it sounds cool and everybody's using it. See the License.txt file for more info.